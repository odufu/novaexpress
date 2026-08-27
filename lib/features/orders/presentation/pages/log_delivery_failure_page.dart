import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/supabase_constants.dart';
import '../../../../core/providers/navigation_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_logo_widget.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/order.dart';
import '../providers/orders_provider.dart';

final logFailureSelectedReasonProvider = StateProvider.autoDispose<String>((ref) => 'Customer Unavailable');
final logFailureLoadingProvider = StateProvider.autoDispose<bool>((ref) => false);
final logFailureSuccessProvider = StateProvider.autoDispose<bool>((ref) => false);

class LogDeliveryFailurePage extends ConsumerStatefulWidget {
  final String orderId;

  const LogDeliveryFailurePage({
    super.key,
    required this.orderId,
  });

  @override
  ConsumerState<LogDeliveryFailurePage> createState() => _LogDeliveryFailurePageState();
}

class _LogDeliveryFailurePageState extends ConsumerState<LogDeliveryFailurePage> {
  final TextEditingController _notesController = TextEditingController();

  final List<Map<String, dynamic>> _reasonsList = [
    {
      'title': 'Customer Unavailable',
      'subtitle': 'No response at location or phone',
      'icon': Icons.doorbell_outlined,
    },
    {
      'title': 'Address Incorrect',
      'subtitle': 'Cannot locate specified address',
      'icon': Icons.wrong_location_outlined,
    },
    {
      'title': 'Payment Refused',
      'subtitle': 'Customer declined to pay (COD)',
      'icon': Icons.credit_card_off_outlined,
    },
    {
      'title': 'Package Damaged',
      'subtitle': 'Item damaged during transit',
      'icon': Icons.broken_image_outlined,
    },
    {
      'title': 'Other Reason',
      'subtitle': 'Specify details in notes below',
      'icon': Icons.more_horiz_rounded,
    },
  ];

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  void _addQuickNote(String tag) {
    if (_notesController.text.isEmpty) {
      _notesController.text = tag;
    } else {
      _notesController.text += ', $tag';
    }
  }

  void _submitFailure() async {
    ref.read(logFailureLoadingProvider.notifier).state = true;

    final authState = ref.read(authProvider);
    final agentId = authState.user?.deliveryAgentId ?? authState.user?.id ?? SupabaseConstants.defaultDeliveryAgentId;
    final selectedReason = ref.read(logFailureSelectedReasonProvider);
    final formattedNotes = _notesController.text.trim().isNotEmpty
        ? '[$selectedReason] ${_notesController.text.trim()}'
        : '[$selectedReason] Delivery failure reported by PDA.';

    String reasonCode = 'other';
    if (selectedReason == 'Customer Unavailable') {
      reasonCode = 'customer_unavailable';
    } else if (selectedReason == 'Wrong / Incomplete Address') {
      reasonCode = 'wrong_address';
    } else if (selectedReason == 'Customer Rescheduled') {
      reasonCode = 'rescheduled';
    } else if (selectedReason == 'Payment Refused') {
      reasonCode = 'cash_shortfall';
    }

    await ref.read(ordersProvider.notifier).logDeliveryFailure(
          orderId: widget.orderId,
          agentId: agentId,
          reasonCode: reasonCode,
          notes: formattedNotes,
        );

    await Future.delayed(const Duration(milliseconds: 600));

    if (mounted) {
      ref.read(logFailureLoadingProvider.notifier).state = false;
      ref.read(logFailureSuccessProvider.notifier).state = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ordersState = ref.watch(ordersProvider);
    final selectedReason = ref.watch(logFailureSelectedReasonProvider);
    final isLoading = ref.watch(logFailureLoadingProvider);
    final isSuccess = ref.watch(logFailureSuccessProvider);

    OrderEntity? matchedOrder;
    for (final o in ordersState.orders) {
      if (o.id == widget.orderId || o.orderNumber == widget.orderId) {
        matchedOrder = o;
        break;
      }
    }

    final order = matchedOrder ?? (ordersState.orders.isNotEmpty
        ? ordersState.orders.first
        : OrderEntity(
            id: widget.orderId,
            orderNumber: 'NVX-8932-441-A',
            customerName: 'Adebayo Oluwaseun',
            customerPhone: '08031234567',
            customerAltPhone: '08099887766',
            deliveryState: 'Lagos',
            deliveryCity: 'Lekki Phase 1',
            deliveryAddress: '42 Admiralty Way, Lekki Phase 1, Lagos',
            status: 'in_transit',
            quantity: 3,
            basePrice: 45000.0,
            upsellAmount: 10000.0,
            totalAmount: 55000.0,
            paymentType: 'pay_on_delivery',
            paymentStatus: 'pending',
            deliveryNotes: 'Call 10 minutes before arrival.',
            createdAt: DateTime.now(),
          ));

    if (isSuccess) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: theme.appBarTheme.backgroundColor,
          elevation: 0.5,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: theme.colorScheme.onSurface),
            onPressed: () {
              ref.read(bottomNavIndexProvider.notifier).state = 1;
              context.go('/');
            },
          ),
          title: Text(
            'FAILURE REPORTED',
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          centerTitle: true,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    color: Color(0xFFBA1A1A),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 48),
                ),
                const SizedBox(height: 20),
                Text(
                  'Failure Report Submitted',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Order #${order.orderNumber} updated to Failed Return. Exception notes logged to Dispatch dashboard.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.orange,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      ref.read(bottomNavIndexProvider.notifier).state = 1;
                      context.go('/');
                    },
                    child: const Text(
                      'RETURN TO ORDERS LIST',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0.5,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: theme.colorScheme.onSurface),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'LOG FAILURE',
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        centerTitle: true,
        actions: [
          const Padding(
            padding: EdgeInsets.only(right: 16),
            child: AppLogoWidget(
              variant: AppLogoVariant.landscape,
              height: 24,
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tracking Summary Header Card matching log_delivery_failure/screen.png
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.15)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Tracking No.',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFBA1A1A),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'REPORTING ISSUE',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '#${order.orderNumber}',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    order.customerName,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined, size: 16, color: theme.colorScheme.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          order.deliveryAddress,
                          style: TextStyle(
                            fontSize: 13,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Select Failure Reason Header matching log_delivery_failure/screen.png
            Text(
              'Select Failure Reason',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Please select the primary reason for delivery failure.',
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),

            // Failure Reasons Selection Cards matching log_delivery_failure/screen.png
            Column(
              children: _reasonsList.map((reason) {
                final isSelected = selectedReason == reason['title'];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary
                          : theme.cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.15),
                      ),
                    ),
                    child: InkWell(
                      onTap: () => ref.read(logFailureSelectedReasonProvider.notifier).state = reason['title'] as String,
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Icon(
                              reason['icon'] as IconData,
                              color: isSelected ? Colors.white : AppColors.orange,
                              size: 22,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    reason['title'] as String,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: isSelected ? Colors.white : theme.colorScheme.onSurface,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    reason['subtitle'] as String,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isSelected ? Colors.white.withValues(alpha: 0.8) : theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isSelected)
                              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // Additional Notes Input matching log_delivery_failure/screen.png
            Text(
              'Additional Notes',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _notesController,
              maxLines: 3,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 14,
                color: theme.colorScheme.onSurface,
              ),
              decoration: InputDecoration(
                hintText: 'Type additional exception details...',
                fillColor: theme.cardColor,
                filled: true,
              ),
            ),
            const SizedBox(height: 10),

            // Quick Note Chips matching log_delivery_failure/screen.png
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _QuickChip(label: 'Gate locked', onTap: () => _addQuickNote('Gate locked')),
                  const SizedBox(width: 6),
                  _QuickChip(label: 'Wrong number', onTap: () => _addQuickNote('Wrong number')),
                  const SizedBox(width: 6),
                  _QuickChip(label: 'Security denied entry', onTap: () => _addQuickNote('Security denied entry')),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Submit Button (Submit Failure Report warning) matching log_delivery_failure/screen.png
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFBA1A1A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: isLoading ? null : _submitFailure,
                icon: const Icon(Icons.warning_amber_rounded, size: 20),
                label: isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text(
                        'Submit Failure Report',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _QuickChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.2)),
        ),
        child: Text(
          '+ $label',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
