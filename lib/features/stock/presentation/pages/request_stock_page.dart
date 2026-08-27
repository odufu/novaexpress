import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/supabase_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../notifications/presentation/providers/notifications_provider.dart';
import '../providers/stock_provider.dart';

final requestStockStepProvider = StateProvider.autoDispose<int>((ref) => 0);
final requestStockSelectedDCProvider = StateProvider.autoDispose<String>((ref) => 'Wuse Distribution Center');

class RequestStockQuantitiesNotifier extends StateNotifier<Map<String, int>> {
  RequestStockQuantitiesNotifier() : super({});

  void increment(String itemName) {
    final current = state[itemName] ?? 0;
    state = {...state, itemName: current + 1};
  }

  void decrement(String itemName) {
    final current = state[itemName] ?? 0;
    if (current > 0) {
      state = {...state, itemName: current - 1};
    }
  }

  void clear() {
    state = {};
  }
}

final requestStockQuantitiesProvider = StateNotifierProvider.autoDispose<
    RequestStockQuantitiesNotifier, Map<String, int>>((ref) {
  return RequestStockQuantitiesNotifier();
});

class RequestStockPage extends ConsumerWidget {
  const RequestStockPage({super.key});

  static const List<String> _distributionCenters = [
    'Wuse Distribution Center',
    'Garki Distribution Center',
    'Kubwa Distribution Center',
    'Ikeja Distribution Center',
  ];

  String _getStepTitle(int currentStep) {
    switch (currentStep) {
      case 0:
        return 'Request Stock: Select Hub';
      case 1:
        return 'Request Stock: Quantities';
      case 2:
        return 'Request Stock: Confirmation';
      default:
        return 'Request Stock';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final stockState = ref.watch(stockProvider);
    final authState = ref.watch(authProvider);
    final currentStep = ref.watch(requestStockStepProvider);
    final selectedDC = ref.watch(requestStockSelectedDCProvider);
    final requestedQuantities = ref.watch(requestStockQuantitiesProvider);

    final user = authState.user;
    final agentName = user != null && user.firstName.isNotEmpty ? '${user.firstName} ${user.lastName}' : 'John Okafor';
    const agentId = 'PDA-0042';

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: theme.colorScheme.onSurface),
          onPressed: () {
            if (currentStep > 0) {
              ref.read(requestStockStepProvider.notifier).state = currentStep - 1;
            } else {
              context.pop();
            }
          },
        ),
        title: Text(
          _getStepTitle(currentStep),
          style: GoogleFonts.inter(
            color: theme.colorScheme.onSurface,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Column(
        children: [
          // Step Progress Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            child: Row(
              children: [
                _buildStepIndicator(0, 'Select DC', isDark, currentStep),
                _buildStepConnector(currentStep >= 1, isDark),
                _buildStepIndicator(1, 'Products', isDark, currentStep),
                _buildStepConnector(currentStep >= 2, isDark),
                _buildStepIndicator(2, 'Review', isDark, currentStep),
              ],
            ),
          ),
          const Divider(height: 1),

          // Main Step Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: _buildStepBody(
                context: context,
                ref: ref,
                currentStep: currentStep,
                stockState: stockState,
                agentName: agentName,
                agentId: agentId,
                selectedDC: selectedDC,
                requestedQuantities: requestedQuantities,
                isDark: isDark,
              ),
            ),
          ),

          // Bottom Action Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              border: Border(
                top: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
            ),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () => _onNextPressed(context, ref, currentStep, selectedDC, requestedQuantities),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  currentStep == 2 ? 'Submit Transfer Request 🚀' : 'Continue',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator(int stepIndex, String title, bool isDark, int currentStep) {
    final isActive = currentStep == stepIndex;
    final isDone = currentStep > stepIndex;

    Color bgColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    Color textColor = const Color(0xFF64748B);

    if (isActive) {
      bgColor = AppColors.primary;
      textColor = Colors.white;
    } else if (isDone) {
      bgColor = const Color(0xFF16A34A);
      textColor = Colors.white;
    }

    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: isDone
              ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
              : Text(
                  '${stepIndex + 1}',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
        ),
        const SizedBox(width: 6),
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
            color: isActive ? (isDark ? Colors.white : const Color(0xFF0F172A)) : const Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  Widget _buildStepConnector(bool isDone, bool isDark) {
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        color: isDone ? const Color(0xFF16A34A) : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
    );
  }

  Widget _buildStepBody({
    required BuildContext context,
    required WidgetRef ref,
    required int currentStep,
    required StockState stockState,
    required String agentName,
    required String agentId,
    required String selectedDC,
    required Map<String, int> requestedQuantities,
    required bool isDark,
  }) {
    switch (currentStep) {
      case 0:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Source Distribution Center',
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Select the hub you will physically collect restocked items from.',
              style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B)),
            ),
            const SizedBox(height: 16),
            ..._distributionCenters.map((dc) {
              final isSelected = selectedDC == dc;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  onTap: () => ref.read(requestStockSelectedDCProvider.notifier).state = dc,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? (isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.3) : const Color(0xFFEEF4FF))
                          : (isDark ? const Color(0xFF1E293B) : Colors.white),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? const Color(0xFF2563EB) : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warehouse_rounded,
                          color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                          size: 24,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                dc,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected ? const Color(0xFF2563EB) : null,
                                ),
                              ),
                              Text(
                                'Open 07:00 AM - 08:00 PM • Verified Hub',
                                style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          const Icon(Icons.check_circle_rounded, color: Color(0xFF2563EB), size: 20),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        );

      case 1:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Product Quantities',
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Specify how many units of each product you need restocked in your vehicle.',
              style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B)),
            ),
            const SizedBox(height: 16),
            ...stockState.stockItems.map((item) {
              final qty = requestedQuantities[item.name] ?? 0;
              final isRequested = qty > 0;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isRequested ? AppColors.primary : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      width: isRequested ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00A2D3).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
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
                              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Owner: ${item.ownerName} • Current: ${item.availableCount} avail',
                              style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline_rounded, color: Color(0xFFE11D48), size: 22),
                            onPressed: () {
                              ref.read(requestStockQuantitiesProvider.notifier).decrement(item.name);
                            },
                          ),
                          Container(
                            constraints: const BoxConstraints(minWidth: 28),
                            alignment: Alignment.center,
                            child: Text(
                              '$qty',
                              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF16A34A), size: 22),
                            onPressed: () {
                              ref.read(requestStockQuantitiesProvider.notifier).increment(item.name);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        );

      case 2:
        final selectedItems = requestedQuantities.entries.where((e) => e.value > 0).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Review Stock Request',
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Verify restock allocation details before transmitting to warehouse.',
              style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B)),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildReviewRow('Source Distribution Center:', selectedDC, isDark),
                  const Divider(height: 20),
                  _buildReviewRow('Assigned Field Agent:', '$agentName ($agentId)', isDark),
                  const Divider(height: 20),
                  _buildReviewRow('Requested Items Count:', '${selectedItems.length} Products', isDark),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Item Allocation Breakdown',
              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            ...selectedItems.map((entry) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(entry.key, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
                      Text(
                        '+${entry.value} units',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF16A34A),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        );

      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildReviewRow(String label, String value, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
        Text(value, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold)),
      ],
    );
  }

  void _onNextPressed(
    BuildContext context,
    WidgetRef ref,
    int currentStep,
    String selectedDC,
    Map<String, int> requestedQuantities,
  ) {
    if (currentStep == 0) {
      ref.read(requestStockStepProvider.notifier).state = 1;
    } else if (currentStep == 1) {
      final hasSelected = requestedQuantities.values.any((qty) => qty > 0);
      if (!hasSelected) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select at least one item quantity to request.'),
            backgroundColor: Color(0xFFE11D48),
          ),
        );
        return;
      }
      ref.read(requestStockStepProvider.notifier).state = 2;
    } else if (currentStep == 2) {
      // Submit stock request
      final cleanQuantities = Map<String, int>.fromEntries(
        requestedQuantities.entries.where((e) => e.value > 0),
      );

      final auth = ref.read(authProvider);
      final agentId = auth.user?.deliveryAgentId ?? auth.user?.id ?? SupabaseConstants.defaultDeliveryAgentId;
      final companyId = auth.user?.companyId ?? '11111111-1111-4111-8111-111111111111';

      ref.read(stockProvider.notifier).addStockRequest(
            dcName: selectedDC,
            quantities: cleanQuantities,
          );

      // Call Edge Function
      ref.read(stockProvider.notifier).requestStockTransfer(
            agentId: agentId,
            companyId: companyId,
            sourceWarehouseId: selectedDC,
            items: cleanQuantities.entries.map((e) => {'product_name': e.key, 'quantity': e.value}).toList(),
            notes: 'Field PDA Stock Transfer Request to $selectedDC',
          );

      ref.read(notificationsProvider.notifier).emitNotification(
            title: 'Stock Request Transmitted 📦',
            message: 'Your restock allocation of ${cleanQuantities.values.fold(0, (a, b) => a + b)} units was sent to $selectedDC.',
            category: 'stock',
            actionRoute: '/stock',
          );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Stock transfer request submitted to distribution center!'),
          backgroundColor: Color(0xFF16A34A),
        ),
      );

      ref.read(requestStockQuantitiesProvider.notifier).clear();
      ref.read(requestStockStepProvider.notifier).state = 0;
      context.pop();
    }
  }
}
