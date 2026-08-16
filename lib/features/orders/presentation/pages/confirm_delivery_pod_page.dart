import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/helpers/formatters.dart';
import '../../../../core/providers/navigation_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_logo_widget.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/order.dart';
import '../providers/orders_provider.dart';

class ConfirmDeliveryPodPage extends ConsumerStatefulWidget {
  final String orderId;

  const ConfirmDeliveryPodPage({
    super.key,
    required this.orderId,
  });

  @override
  ConsumerState<ConfirmDeliveryPodPage> createState() => _ConfirmDeliveryPodPageState();
}

class _ConfirmDeliveryPodPageState extends ConsumerState<ConfirmDeliveryPodPage> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _referenceController = TextEditingController();
  String _selectedPaymentMethod = 'Cash'; // 'Cash', 'Bank Transfer', 'POS Terminal'
  bool _hasConfirmedReceipt = true;
  bool _isLoading = false;
  bool _isSuccess = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ordersState = ref.read(ordersProvider);
      OrderEntity? matchedOrder;
      for (final o in ordersState.orders) {
        if (o.id == widget.orderId || o.orderNumber == widget.orderId) {
          matchedOrder = o;
          break;
        }
      }
      final order = matchedOrder ?? (ordersState.orders.isNotEmpty ? ordersState.orders.first : null);
      if (order != null) {
        _amountController.text = order.totalAmount.toStringAsFixed(0);
      }
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _referenceController.dispose();
    super.dispose();
  }

  void _submitDelivery() async {
    setState(() {
      _isLoading = true;
    });

    await ref.read(ordersProvider.notifier).updateOrderStatus(
          widget.orderId,
          'delivered',
        );

    await Future.delayed(const Duration(milliseconds: 600));

    if (mounted) {
      setState(() {
        _isLoading = false;
        _isSuccess = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = ref.watch(authProvider);
    final ordersState = ref.watch(ordersProvider);

    final user = authState.user;
    final agentName = user != null && user.firstName.isNotEmpty ? user.firstName : 'Emeka';

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
            orderNumber: 'TRK-8924-NIG',
            customerName: 'Chief Aliyu Mohammed',
            customerPhone: '08031234567',
            customerAltPhone: '08099887766',
            deliveryState: 'Lagos',
            deliveryCity: 'Lekki Phase 1',
            deliveryAddress: 'Lekki Phase 1, Lagos',
            status: 'in_transit',
            quantity: 3,
            basePrice: 20000.0,
            upsellAmount: 7500.0,
            totalAmount: 27500.0,
            paymentType: 'pay_on_delivery',
            paymentStatus: 'pending',
            deliveryNotes: 'Call 10 minutes before arrival.',
            createdAt: DateTime.now(),
          ));

    if (_isSuccess) {
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
            'POD CONFIRMED',
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
                    color: Color(0xFF00522A),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_rounded, color: Colors.white, size: 48),
                ),
                const SizedBox(height: 20),
                Text(
                  'Delivery Confirmed!',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Shipment #${order.orderNumber} successfully marked as delivered. Cash balance updated in Finance.',
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
          'CONFIRM POD',
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
            // Shipment ID Hero Card matching confirm_delivery_pod/screen.png
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
                        'Shipment ID',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        '#${order.orderNumber}',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.widgets_outlined, size: 16, color: theme.colorScheme.onSurfaceVariant),
                      const SizedBox(width: 6),
                      Text(
                        '${order.quantity}x Industrial Valves Package',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined, size: 16, color: theme.colorScheme.onSurfaceVariant),
                      const SizedBox(width: 6),
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
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total to Collect',
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        CurrencyFormatter.formatNaira(order.totalAmount),
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.orange,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Amount Collected Field matching confirm_delivery_pod/screen.png
            Text(
              'Amount Collected (₦)',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
              decoration: InputDecoration(
                prefixText: '₦ ',
                prefixStyle: GoogleFonts.jetBrainsMono(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.orange,
                ),
                fillColor: theme.cardColor,
                filled: true,
              ),
            ),
            const SizedBox(height: 20),

            // Payment Method Selector Chips matching confirm_delivery_pod/screen.png
            Text(
              'Payment Method',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedPaymentMethod = 'Cash'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _selectedPaymentMethod == 'Cash' ? AppColors.primary : theme.colorScheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          'Cash',
                          style: TextStyle(
                            color: _selectedPaymentMethod == 'Cash' ? Colors.white : theme.colorScheme.onSurface,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedPaymentMethod = 'Bank Transfer'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _selectedPaymentMethod == 'Bank Transfer' ? AppColors.primary : theme.colorScheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          'Bank Transfer',
                          style: TextStyle(
                            color: _selectedPaymentMethod == 'Bank Transfer' ? Colors.white : theme.colorScheme.onSurface,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedPaymentMethod = 'POS Terminal'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _selectedPaymentMethod == 'POS Terminal' ? AppColors.primary : theme.colorScheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          'POS Terminal',
                          style: TextStyle(
                            color: _selectedPaymentMethod == 'POS Terminal' ? Colors.white : theme.colorScheme.onSurface,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (_selectedPaymentMethod != 'Cash') ...[
              Text(
                'Reference Number',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _referenceController,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 14,
                  color: theme.colorScheme.onSurface,
                ),
                decoration: InputDecoration(
                  hintText: 'Enter Transaction Ref / RRR',
                  suffixIcon: const Icon(Icons.arrow_drop_down),
                  fillColor: theme.cardColor,
                  filled: true,
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Customer Confirmed Receipt Checkbox matching confirm_delivery_pod/screen.png
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.15)),
              ),
              child: CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                activeColor: AppColors.orange,
                title: Text(
                  'Customer Confirmed Receipt',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                subtitle: Text(
                  'Verify condition of goods before checking.',
                  style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                ),
                value: _hasConfirmedReceipt,
                onChanged: (val) {
                  if (val != null) setState(() => _hasConfirmedReceipt = val);
                },
              ),
            ),
            const SizedBox(height: 24),

            // Submit Button (Confirm & Complete task_alt) matching confirm_delivery_pod/screen.png
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00522A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _isLoading || !_hasConfirmedReceipt ? null : _submitDelivery,
                icon: const Icon(Icons.task_alt_rounded, size: 20),
                label: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text(
                        'Confirm & Complete',
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
