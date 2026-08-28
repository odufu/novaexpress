import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/helpers/formatters.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/stock_item.dart';
import '../providers/stock_provider.dart';

class ReturnStockDraftState {
  final StockItemEntity? selectedItem;
  final int returnQuantity;
  final String returnReason;
  final bool isSubmitting;

  const ReturnStockDraftState({
    this.selectedItem,
    this.returnQuantity = 1,
    this.returnReason = 'End of Day Unsold Hub Drop-off',
    this.isSubmitting = false,
  });

  ReturnStockDraftState copyWith({
    StockItemEntity? Function()? selectedItem,
    int? returnQuantity,
    String? returnReason,
    bool? isSubmitting,
  }) {
    return ReturnStockDraftState(
      selectedItem: selectedItem != null ? selectedItem() : this.selectedItem,
      returnQuantity: returnQuantity ?? this.returnQuantity,
      returnReason: returnReason ?? this.returnReason,
      isSubmitting: isSubmitting ?? this.isSubmitting,
    );
  }
}

class ReturnStockDraftNotifier extends StateNotifier<ReturnStockDraftState> {
  ReturnStockDraftNotifier([StockItemEntity? initialItem])
      : super(ReturnStockDraftState(selectedItem: initialItem));

  void selectItem(StockItemEntity? item) {
    state = state.copyWith(
      selectedItem: () => item,
      returnQuantity: 1,
    );
  }

  void incrementQuantity(int maxUnits) {
    if (state.returnQuantity < maxUnits) {
      state = state.copyWith(returnQuantity: state.returnQuantity + 1);
    }
  }

  void decrementQuantity() {
    if (state.returnQuantity > 1) {
      state = state.copyWith(returnQuantity: state.returnQuantity - 1);
    }
  }

  void setReason(String reason) => state = state.copyWith(returnReason: reason);
  void setSubmitting(bool val) => state = state.copyWith(isSubmitting: val);
}

final returnStockDraftProvider = StateNotifierProvider.autoDispose<ReturnStockDraftNotifier, ReturnStockDraftState>((ref) {
  return ReturnStockDraftNotifier();
});

class ReturnStockModal extends ConsumerStatefulWidget {
  final StockItemEntity? preselectedItem;

  const ReturnStockModal({
    super.key,
    this.preselectedItem,
  });

  static Future<void> show(
    BuildContext context, {
    StockItemEntity? preselectedItem,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520, maxHeight: 720),
          child: ReturnStockModal(preselectedItem: preselectedItem),
        ),
      ),
    );
  }

  @override
  ConsumerState<ReturnStockModal> createState() => _ReturnStockModalState();
}

class _ReturnStockModalState extends ConsumerState<ReturnStockModal> {
  final TextEditingController _notesCtrl = TextEditingController();

  final List<String> _reasons = [
    'End of Day Unsold Hub Drop-off',
    'Customer Refusal / Cancelled Delivery',
    'Damaged / Leaking in Transit',
    'Expired / Stale Stock',
    'DC Recall / Excess Stock Rebalancing',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.preselectedItem != null) {
        ref.read(returnStockDraftProvider.notifier).selectItem(widget.preselectedItem);
      }
    });
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final authState = ref.watch(authProvider);
    final stockState = ref.watch(stockProvider);
    final draft = ref.watch(returnStockDraftProvider);

    final riderId = authState.user?.id ?? 'a1111111-1111-4111-8111-111111111111';
    final riderAllocations = stockState.getAllocationsForRider(
      riderId,
      authState.user?.riderCode ?? 'PDA-7000',
    );

    final availableVehicleItems = stockState.stockItems.where((item) {
      final alloc = riderAllocations.firstWhere(
        (a) => a.productName.toLowerCase().trim() == item.name.toLowerCase().trim() ||
               a.productId == item.id,
        orElse: () => riderAllocations.isNotEmpty ? riderAllocations.first : riderAllocations.first,
      );
      return alloc.inCustodyUnits > 0 || item.availableCount > 0;
    }).toList();

    // Find active selection
    StockItemEntity? currentItem = draft.selectedItem;
    if (currentItem == null && availableVehicleItems.isNotEmpty) {
      currentItem = widget.preselectedItem ?? availableVehicleItems.first;
    }

    int maxReturnUnits = 0;
    if (currentItem != null) {
      final matchingAlloc = riderAllocations.firstWhere(
        (a) => a.productName.toLowerCase().trim() == currentItem!.name.toLowerCase().trim() ||
               a.productId == currentItem.id,
        orElse: () => riderAllocations.isNotEmpty ? riderAllocations.first : riderAllocations.first,
      );
      maxReturnUnits = matchingAlloc.inCustodyUnits > 0 ? matchingAlloc.inCustodyUnits : currentItem.availableCount;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEA580C).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.assignment_return_rounded, color: Color(0xFFEA580C), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Return Stock to Host DC',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        'Direct reconciliation with DC Warehouse inventory',
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),

          // 2. Content Form
          Flexible(
            child: availableVehicleItems.isEmpty && (currentItem == null || maxReturnUnits <= 0)
                ? Container(
                    padding: const EdgeInsets.all(24),
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.inventory_2_outlined, size: 48, color: Color(0xFF94A3B8)),
                        const SizedBox(height: 12),
                        Text(
                          'No Physical Stock in Vehicle Custody',
                          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'You do not have any units in vehicle custody to return to the DC warehouse at this time.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Product Selection
                        Text('Select Product in Custody *', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12.5)),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<StockItemEntity>(
                              value: currentItem,
                              isExpanded: true,
                              dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                              items: (availableVehicleItems.isNotEmpty ? availableVehicleItems : (currentItem != null ? [currentItem] : <StockItemEntity>[]))
                                  .map((item) {
                                return DropdownMenuItem<StockItemEntity>(
                                  value: item,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          item.name,
                                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          '${item.availableCount} in vehicle',
                                          style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.bold, color: const Color(0xFF8B5CF6)),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  ref.read(returnStockDraftProvider.notifier).selectItem(val);
                                }
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Return Quantity Stepper
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Quantity to Return *', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12.5)),
                                Text('Max on vehicle: $maxReturnUnits units', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B))),
                              ],
                            ),
                            Container(
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                              ),
                              child: Row(
                                children: [
                                  IconButton(
                                    onPressed: draft.returnQuantity > 1
                                        ? () => ref.read(returnStockDraftProvider.notifier).decrementQuantity()
                                        : null,
                                    icon: const Icon(Icons.remove_rounded, size: 18),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                    child: Text(
                                      '${draft.returnQuantity}',
                                      style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: draft.returnQuantity < maxReturnUnits
                                        ? () => ref.read(returnStockDraftProvider.notifier).incrementQuantity(maxReturnUnits)
                                        : null,
                                    icon: const Icon(Icons.add_rounded, size: 18),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Return Reason
                        Text('Reason for Return *', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12.5)),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: draft.returnReason,
                              isExpanded: true,
                              dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                              items: _reasons.map((r) {
                                return DropdownMenuItem<String>(
                                  value: r,
                                  child: Text(r, style: GoogleFonts.inter(fontSize: 12.5)),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  ref.read(returnStockDraftProvider.notifier).setReason(val);
                                }
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Notes Field
                        Text('Additional Notes / Hub Receiver', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12.5)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _notesCtrl,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            hintText: 'e.g. Returned to Supervisor Emeka at Lekki Hub',
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Real-time Valuation Preview
                        if (currentItem != null)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEA580C).withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFEA580C).withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Return Value Credit:', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B))),
                                    Text(
                                      CurrencyFormatter.formatNaira(currentItem.price * draft.returnQuantity),
                                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFFEA580C)),
                                    ),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text('New Vehicle Balance:', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B))),
                                    Text(
                                      '${maxReturnUnits - draft.returnQuantity} Units',
                                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
          ),

          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // 3. Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: (currentItem == null || maxReturnUnits <= 0 || draft.isSubmitting)
                    ? null
                    : () async {
                        ref.read(returnStockDraftProvider.notifier).setSubmitting(true);
                        final item = currentItem!;
                        final res = await ref.read(stockProvider.notifier).returnStockToDC(
                              productIdOrSku: item.id,
                              riderId: riderId,
                              quantity: draft.returnQuantity,
                              reason: draft.returnReason,
                              notes: _notesCtrl.text.trim(),
                            );

                        if (context.mounted) {
                          ref.read(returnStockDraftProvider.notifier).setSubmitting(false);
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: const Color(0xFF10B981),
                              content: Text(res['message']?.toString() ?? 'Stock returned successfully!'),
                            ),
                          );
                        }
                      },
                icon: const Icon(Icons.assignment_return_rounded, size: 16, color: Colors.white),
                label: Text(
                  draft.isSubmitting ? 'Processing...' : 'Confirm Return to DC',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEA580C),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
