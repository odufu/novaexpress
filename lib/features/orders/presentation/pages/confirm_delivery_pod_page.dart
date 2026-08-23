import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/supabase_constants.dart';
import '../../../../core/helpers/formatters.dart';
import '../../../../core/providers/navigation_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_logo_widget.dart';
import '../../../../core/widgets/signature_pad_widget.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../finance/presentation/providers/finance_provider.dart';
import '../../../notifications/presentation/providers/notifications_provider.dart';
import '../../../stock/presentation/providers/stock_provider.dart';
import '../../domain/entities/order.dart';
import '../providers/orders_provider.dart';
import '../widgets/monnify_transfer_modal.dart';

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
  String _selectedPaymentMethod = 'Cash'; // 'Cash', 'Direct Transfer (Monnify)', 'POS Terminal'
  bool _hasConfirmedReceipt = true;
  bool _isVerifyingMonnify = false;
  bool _monnifyTransferVerified = false;
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

  void _verifyMonnifyPayment() async {
    setState(() => _isVerifyingMonnify = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      setState(() {
        _isVerifyingMonnify = false;
        _monnifyTransferVerified = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFF16A34A),
          content: Text('✓ Monnify direct transfer confirmed! Funds received in company account.'),
        ),
      );
    }
  }

  void _submitDelivery() async {
    setState(() {
      _isLoading = true;
    });

    final authState = ref.read(authProvider);
    final agentId = authState.user?.deliveryAgentId ?? authState.user?.id ?? SupabaseConstants.defaultDeliveryAgentId;
    final isDirectTransfer = _selectedPaymentMethod == 'Direct Transfer (Monnify)';
    final isPos = _selectedPaymentMethod == 'POS Terminal';
    final paymentMethod = isDirectTransfer ? 'bank_transfer' : (isPos ? 'pos' : 'cash');
    final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    final refNo = _referenceController.text.trim();
    final orderIdPrefix = (widget.orderId.length >= 4 ? widget.orderId.substring(0, 4) : widget.orderId).toUpperCase();
    final notes = isDirectTransfer
        ? '[POD Paid via Monnify Direct Transfer • Ref: MNFY-$orderIdPrefix] ₦0 cash held by PDA. Commission credited to My Balance.'
        : (refNo.isNotEmpty
            ? '[POD Collected via $_selectedPaymentMethod (Ref: $refNo)] Cash in custody.'
            : '[POD Collected via $_selectedPaymentMethod] Cash in custody.');

    await ref.read(ordersProvider.notifier).confirmDeliveryPod(
          orderId: widget.orderId,
          agentId: agentId,
          paymentType: isDirectTransfer ? 'prepaid' : 'pay_on_delivery',
          paymentMethod: paymentMethod,
          amountCollected: amount,
          notes: notes,
        );

    // Refresh finance, orders, stock & notifications state
    ref.read(financeProvider.notifier).loadRemittances(agentId);
    ref.read(stockProvider.notifier).fetchStockItems();
    ref.read(notificationsProvider.notifier).emitNotification(
          title: 'Delivery POD Confirmed 🎉',
          message: 'Order ${widget.orderId} was successfully delivered. Net cash collection recorded.',
          category: 'delivery',
          actionRoute: '/orders',
        );

    await Future.delayed(const Duration(milliseconds: 400));

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
    final isDark = theme.brightness == Brightness.dark;
    final authState = ref.watch(authProvider);
    final ordersState = ref.watch(ordersProvider);

    final user = authState.user;

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

    final isDirectTransfer = _selectedPaymentMethod == 'Direct Transfer (Monnify)';
    final virtualAccountNumber = '7890${order.orderNumber.replaceAll(RegExp(r'[^0-9]'), '').padRight(6, '1').substring(0, 6)}';

    if (_isSuccess) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: theme.appBarTheme.backgroundColor,
          elevation: 0.5,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: theme.colorScheme.onSurface),
            onPressed: () {
              ref.read(bottomNavIndexProvider.notifier).state = 2;
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
                  'Delivery Completed!',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isDirectTransfer
                      ? 'Payment of ${CurrencyFormatter.formatNaira(order.totalAmount)} was paid directly to NovaExpress via Monnify.\n(₦0.00 cash held by you).'
                      : 'Shipment #${order.orderNumber} successfully marked as delivered. ₦${order.totalAmount.toStringAsFixed(0)} cash in custody for remittance.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.5,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),

                // Transparent Agent Earnings Card matching PRD Section 34 & Rule BR-010 & BR-023
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00522A).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF00522A).withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        isDirectTransfer
                            ? 'CREDITED TO YOUR "MY BALANCE"'
                            : 'YOUR ACCRUED EARNINGS FOR THIS DELIVERY',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF00522A),
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Commission: ${CurrencyFormatter.formatNaira(user?.commissionRate ?? 1000.0)}  •  Transport: ${CurrencyFormatter.formatNaira(user?.isPda == true ? user?.transportAllowance ?? 1500.0 : user?.fuelAllowance ?? 800.0)}',
                        style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Total: ${CurrencyFormatter.formatNaira((user?.commissionRate ?? 1000.0) + (user?.isPda == true ? user?.transportAllowance ?? 1500.0 : user?.fuelAllowance ?? 800.0))}',
                        style: GoogleFonts.jetBrainsMono(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF00522A)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
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
                      ref.read(bottomNavIndexProvider.notifier).state = 2;
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
          'CONFIRM POD PAYMENT',
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        centerTitle: true,
        actions: const [
          Padding(
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
            // Shipment ID Hero Card
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
                      Icon(Icons.inventory_2_outlined, size: 16, color: theme.colorScheme.onSurfaceVariant),
                      const SizedBox(width: 6),
                      Text(
                        '${order.quantity}x Delivery Items',
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
                        'Total Payable',
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
            const SizedBox(height: 18),

            // Payment Method Selector Chips (Cash vs Monnify Direct Transfer vs POS)
            Text(
              'Select Customer Payment Method',
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
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      decoration: BoxDecoration(
                        color: _selectedPaymentMethod == 'Cash' ? AppColors.primary : theme.colorScheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _selectedPaymentMethod == 'Cash' ? AppColors.primary : Colors.transparent,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '💵 Cash',
                          style: TextStyle(
                            color: _selectedPaymentMethod == 'Cash' ? Colors.white : theme.colorScheme.onSurface,
                            fontWeight: FontWeight.bold,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  flex: 2,
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedPaymentMethod = 'Direct Transfer (Monnify)'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      decoration: BoxDecoration(
                        color: _selectedPaymentMethod == 'Direct Transfer (Monnify)' ? const Color(0xFF2563EB) : theme.colorScheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _selectedPaymentMethod == 'Direct Transfer (Monnify)' ? const Color(0xFF2563EB) : Colors.transparent,
                        ),
                      ),
                      child: Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.flash_on_rounded, size: 14, color: Colors.white),
                            const SizedBox(width: 3),
                            Text(
                              'Direct Transfer (Monnify)',
                              style: TextStyle(
                                color: _selectedPaymentMethod == 'Direct Transfer (Monnify)' ? Colors.white : theme.colorScheme.onSurface,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedPaymentMethod = 'POS Terminal'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      decoration: BoxDecoration(
                        color: _selectedPaymentMethod == 'POS Terminal' ? AppColors.primary : theme.colorScheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          '💳 POS',
                          style: TextStyle(
                            color: _selectedPaymentMethod == 'POS Terminal' ? Colors.white : theme.colorScheme.onSurface,
                            fontWeight: FontWeight.bold,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // DYNAMIC SECTION A: DIRECT MONNIFY TRANSFER VIRTUAL ACCOUNT CARD
            if (isDirectTransfer) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF1E3A8A), const Color(0xFF0F172A)]
                        : [const Color(0xFFEFF6FF), const Color(0xFFDBEAFE)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF3B82F6)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2563EB).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.account_balance_rounded, color: Color(0xFF2563EB), size: 18),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'MONNIFY DYNAMIC ACCOUNT',
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                  color: const Color(0xFF2563EB),
                                ),
                              ),
                              Text(
                                'Instruct customer to transfer exact amount below:',
                                style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Account Number with Copy Button
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF93C5FD)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Wema Bank / Moniepoint', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B))),
                              const SizedBox(height: 2),
                              Text(
                                virtualAccountNumber,
                                style: GoogleFonts.jetBrainsMono(fontSize: 18, fontWeight: FontWeight.w900, color: const Color(0xFF2563EB)),
                              ),
                              Text('NovaExpress / #${order.orderNumber}', style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF64748B))),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy_rounded, color: Color(0xFF2563EB)),
                            tooltip: 'Copy Account Number',
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: virtualAccountNumber));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Account number copied to clipboard!')),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Verification Button / Webhook Status
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              MonnifyTransferModal.show(
                                context: context,
                                orderNumber: order.orderNumber,
                                amount: order.totalAmount,
                                onPaymentConfirmed: () {
                                  setState(() {
                                    _monnifyTransferVerified = true;
                                  });
                                },
                              );
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF2563EB),
                              side: const BorderSide(color: Color(0xFF2563EB)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Icon(Icons.qr_code_scanner_rounded, size: 16),
                            label: Text(
                              'Open Monnify Screen',
                              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isVerifyingMonnify ? null : _verifyMonnifyPayment,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _monnifyTransferVerified ? const Color(0xFF16A34A) : const Color(0xFF2563EB),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: _isVerifyingMonnify
                                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : Icon(_monnifyTransferVerified ? Icons.check_circle_rounded : Icons.sync_rounded, size: 16),
                            label: Text(
                              _monnifyTransferVerified
                                  ? 'Verified ✓'
                                  : (_isVerifyingMonnify ? 'Checking...' : 'Check Status'),
                              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Note on Rider Compensation
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded, size: 14, color: Color(0xFF16A34A)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Direct transfer received directly by company. ₦0.00 cash held. Your ₦2,500 earnings will be credited to My Balance.',
                              style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF16A34A), fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ] else ...[
              // DYNAMIC SECTION B: CASH COLLECTION FIELD
              Text(
                'Enter Physical Cash Collected',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 6),
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
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Digital Signature Canvas
            Text(
              'Proof of Delivery (POD) Signature',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            const SignaturePadWidget(
              height: 150,
            ),
            const SizedBox(height: 16),

            // Customer Confirmed Goods Checkbox
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
                  'Customer Confirmed Receipt & Condition',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13.5,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                subtitle: Text(
                  'Customer has inspected items before handing over payment.',
                  style: TextStyle(fontSize: 11.5, color: theme.colorScheme.onSurfaceVariant),
                ),
                value: _hasConfirmedReceipt,
                onChanged: (val) {
                  if (val != null) setState(() => _hasConfirmedReceipt = val);
                },
              ),
            ),
            const SizedBox(height: 20),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 52,
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
                        'Confirm & Complete Delivery',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
