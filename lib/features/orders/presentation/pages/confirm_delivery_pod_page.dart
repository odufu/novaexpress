import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/supabase_constants.dart';
import '../../../../core/helpers/formatters.dart';
import '../../../../core/providers/navigation_provider.dart';
import '../../../../core/services/rider_location_service.dart';
import '../../../../core/services/signature_storage_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_logo_widget.dart';
import '../../../../core/widgets/signature_pad_modal.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../finance/presentation/providers/finance_provider.dart';
import '../../../notifications/presentation/providers/notifications_provider.dart';
import '../../../stock/presentation/providers/stock_provider.dart';
import '../../domain/entities/order.dart';
import '../providers/orders_provider.dart';

class ConfirmDeliveryPodState {
  final String selectedPaymentMethod;
  final bool hasConfirmedReceipt;
  final bool isLoading;
  final bool isSuccess;
  final Uint8List? signatureBytes;
  final String? signatureUrl;
  final Uint8List? photoBytes;
  final String? photoUrl;
  final String? errorMessage;
  final double enteredAmount;

  const ConfirmDeliveryPodState({
    this.selectedPaymentMethod = 'Cash',
    this.hasConfirmedReceipt = true,
    this.isLoading = false,
    this.isSuccess = false,
    this.signatureBytes,
    this.signatureUrl,
    this.photoBytes,
    this.photoUrl,
    this.errorMessage,
    this.enteredAmount = 0.0,
  });

  ConfirmDeliveryPodState copyWith({
    String? selectedPaymentMethod,
    bool? hasConfirmedReceipt,
    bool? isLoading,
    bool? isSuccess,
    Uint8List? signatureBytes,
    String? signatureUrl,
    Uint8List? photoBytes,
    String? photoUrl,
    String? errorMessage,
    double? enteredAmount,
  }) {
    return ConfirmDeliveryPodState(
      selectedPaymentMethod: selectedPaymentMethod ?? this.selectedPaymentMethod,
      hasConfirmedReceipt: hasConfirmedReceipt ?? this.hasConfirmedReceipt,
      isLoading: isLoading ?? this.isLoading,
      isSuccess: isSuccess ?? this.isSuccess,
      signatureBytes: signatureBytes ?? this.signatureBytes,
      signatureUrl: signatureUrl ?? this.signatureUrl,
      photoBytes: photoBytes ?? this.photoBytes,
      photoUrl: photoUrl ?? this.photoUrl,
      errorMessage: errorMessage,
      enteredAmount: enteredAmount ?? this.enteredAmount,
    );
  }
}

class ConfirmDeliveryPodNotifier extends StateNotifier<ConfirmDeliveryPodState> {
  ConfirmDeliveryPodNotifier() : super(const ConfirmDeliveryPodState());

  void setPaymentMethod(String method) {
    state = state.copyWith(selectedPaymentMethod: method);
  }

  void setConfirmedReceipt(bool confirmed) {
    state = state.copyWith(hasConfirmedReceipt: confirmed);
  }

  void setLoading(bool loading) {
    state = state.copyWith(isLoading: loading);
  }

  void setSuccess() {
    state = state.copyWith(isLoading: false, isSuccess: true, errorMessage: null);
  }

  void setError(String error) {
    state = state.copyWith(isLoading: false, errorMessage: error);
  }

  void setSignature(Uint8List? bytes, String? url) {
    state = state.copyWith(signatureBytes: bytes, signatureUrl: url);
  }

  void setPhoto(Uint8List? bytes, String? url) {
    state = state.copyWith(photoBytes: bytes, photoUrl: url);
  }

  void setEnteredAmount(double amt) {
    state = state.copyWith(enteredAmount: amt);
  }
}

final confirmDeliveryPodProvider =
    StateNotifierProvider.autoDispose<ConfirmDeliveryPodNotifier, ConfirmDeliveryPodState>((ref) {
  return ConfirmDeliveryPodNotifier();
});

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
        ref.read(confirmDeliveryPodProvider.notifier).setEnteredAmount(order.totalAmount);
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
    final podState = ref.read(confirmDeliveryPodProvider);

    ref.read(confirmDeliveryPodProvider.notifier).setLoading(true);

    try {
      final authState = ref.read(authProvider);
      final agentId = authState.user?.deliveryAgentId ?? authState.user?.id ?? SupabaseConstants.defaultDeliveryAgentId;
      const paymentMethod = 'cash';
      final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;
      final refNo = _referenceController.text.trim();
      final riderLoc = ref.read(riderLocationProvider);
      final ordersState = ref.read(ordersProvider);
      final orderObj = ordersState.orders.where((o) => o.id == widget.orderId || o.orderNumber == widget.orderId).firstOrNull;
      final gatePin = orderObj?.effectiveGatePin ?? 'GT-${(widget.orderId.length >= 4 ? widget.orderId.substring(widget.orderId.length - 4) : "7182").toUpperCase()}';

      final notes = refNo.isNotEmpty
          ? '[POD Collected via Cash (Ref: $refNo) • Gate PIN: $gatePin • GPS Proof: ${riderLoc.latitude.toStringAsFixed(5)}°, ${riderLoc.longitude.toStringAsFixed(5)}° (±${riderLoc.accuracyMeters.toStringAsFixed(1)}m)] Cash in custody.'
          : '[POD Collected via Cash • Gate PIN: $gatePin • GPS Proof: ${riderLoc.latitude.toStringAsFixed(5)}°, ${riderLoc.longitude.toStringAsFixed(5)}° (±${riderLoc.accuracyMeters.toStringAsFixed(1)}m)] Cash in custody.';

      await ref.read(ordersProvider.notifier).confirmDeliveryPod(
            orderId: widget.orderId,
            agentId: agentId,
            paymentType: 'pay_on_delivery',
            paymentMethod: paymentMethod,
            amountCollected: amount,
            customerSignatureUrl: podState.signatureUrl,
            photoProofUrl: podState.photoUrl,
            gatePassCode: gatePin,
            latitude: riderLoc.latitude,
            longitude: riderLoc.longitude,
            notes: notes,
          );
      
      // Automatically deduct delivered physical stock units from vehicle custody
      if (orderObj != null) {
        final prodName = orderObj.productName.isNotEmpty ? orderObj.productName : (orderObj.productSku ?? 'Product Item');
        final physicalQty = orderObj.quantity > 0 ? orderObj.quantity : 1;
        await ref.read(stockProvider.notifier).recordDeliveredOrderStock(
              productNameOrSku: prodName,
              riderId: agentId,
              physicalQuantity: physicalQty,
            );
      }

      // Refresh finance, orders, stock & notifications state
      ref.read(financeProvider.notifier).loadRemittances(agentId);
      final displayOrderNo = orderObj?.orderNumber ?? (widget.orderId.length > 8 ? 'NX-${widget.orderId.substring(0, 4).toUpperCase()}' : widget.orderId);

      ref.read(notificationsProvider.notifier).emitNotification(
            title: 'Delivery POD Confirmed 🎉',
            message: 'Order $displayOrderNo was successfully delivered. Net collection of ${CurrencyFormatter.formatNaira(amount)} recorded in cash custody.',
            category: 'delivery',
            actionRoute: '/orders',
          );

      await Future.delayed(const Duration(milliseconds: 600));

      if (mounted) {
        ref.read(confirmDeliveryPodProvider.notifier).setSuccess();
      }
    } catch (e) {
      if (mounted) {
        ref.read(confirmDeliveryPodProvider.notifier).setError(e.toString());
      }
    }
  }

  Future<void> _pickOrCapturePhotoProof() async {
    try {
      final result = await FilePickerPlatform.instance.pickFiles(
        type: FileType.image,
      );

      if (result.isNotEmpty) {
        final file = result.first;
        final bytes = await file.readAsBytes();
        if (bytes.isNotEmpty) {
          final ext = file.extension?.toLowerCase() ?? 'jpg';
          final contentType = ext == 'png' ? 'image/png' : (ext == 'webp' ? 'image/webp' : 'image/jpeg');
          
          final publicUrl = await SignatureStorageService.uploadDeliveryProofPhoto(
            imageBytes: bytes,
            orderId: widget.orderId,
            ext: ext,
            contentType: contentType,
          );
          
          ref.read(confirmDeliveryPodProvider.notifier).setPhoto(bytes, publicUrl);
          debugPrint('[POD] ✅ POD Photo proof stored with URL: $publicUrl');
        }
      }
    } catch (e) {
      debugPrint('[POD] ⚠️ Photo picking error: $e');
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

    final podState = ref.watch(confirmDeliveryPodProvider);

    final commissionRate = user?.commissionRate ?? 1000.0;
    final transportAllowance = user?.isPda == true
        ? (user?.transportAllowance ?? 1500.0)
        : (user?.fuelAllowance ?? 800.0);

    final enteredCash = double.tryParse(_amountController.text.trim()) ?? order.totalAmount;
    final cashTransferFee = TransactionFeeCalculator.calculateTransferFee(enteredCash);
    final totalRetainedByRider = commissionRate + transportAllowance + cashTransferFee;
    final netCashRemittance = (enteredCash - commissionRate - transportAllowance - cashTransferFee).clamp(0.0, double.infinity);

    // ==========================================
    // 1. FULL-PAGE PROCESSING / LOADER SCREEN
    // ==========================================
    if (podState.isLoading) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: theme.appBarTheme.backgroundColor,
          elevation: 0.5,
          automaticallyImplyLeading: false,
          title: Text(
            'PROCESSING DELIVERY',
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontSize: 15,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          centerTitle: true,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 84,
                      height: 84,
                      child: CircularProgressIndicator(
                        strokeWidth: 4,
                        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.orange),
                        backgroundColor: AppColors.orange.withValues(alpha: 0.15),
                      ),
                    ),
                    const Icon(
                      Icons.local_shipping_rounded,
                      size: 38,
                      color: AppColors.orange,
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                Text(
                  'Confirming POD Delivery...',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Logging customer digital signature, updating inventory quantities, and preparing cash remittance ledger...',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    height: 1.5,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Shipment #${order.orderNumber}',
                        style: GoogleFonts.jetBrainsMono(fontSize: 11.5, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // ==========================================
    // 2. FULL-PAGE FAILURE SCREEN
    // ==========================================
    if (podState.errorMessage != null) {
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
            'DELIVERY STATUS',
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
                  decoration: BoxDecoration(
                    color: const Color(0xFFDC2626).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 48),
                ),
                const SizedBox(height: 20),
                Text(
                  'Delivery Confirmation Failed',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  podState.errorMessage!,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: const Color(0xFFDC2626),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.orange,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _submitDelivery,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('RETRY CONFIRMATION', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      ref.read(bottomNavIndexProvider.notifier).state = 2;
                      context.go('/');
                    },
                    child: const Text('RETURN TO ORDERS LIST', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // ==========================================
    // 3. FULL-PAGE SUCCESS RECEIPT SCREEN
    // ==========================================
    if (podState.isSuccess) {
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
                  'Shipment #${order.orderNumber} successfully marked as delivered. ${CurrencyFormatter.formatNaira(order.totalAmount)} cash in custody for remittance.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.5,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),

                // Transparent Agent Earnings Card
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
                        'YOUR ACCRUED EARNINGS FOR THIS DELIVERY',
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
                      Expanded(
                        child: Text(
                          'Total Payable',
                          style: TextStyle(
                            fontSize: 13,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        CurrencyFormatter.formatNaira(order.totalAmount),
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 20,
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

            // Payment Method: Enforced Cash POD
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF00522A).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF00522A).withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00522A),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.payments_rounded, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Payment Method: Cash POD',
                          style: GoogleFonts.inter(
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF00522A),
                          ),
                        ),
                        Text(
                          'Collect cash from customer before handing over package.',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00522A),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'CASH POD',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
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
                onChanged: (v) => ref.read(confirmDeliveryPodProvider.notifier).setEnteredAmount(double.tryParse(v) ?? 0.0),
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
              const SizedBox(height: 12),

              // Cash Remittance & Settlement Breakdown Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'CASH REMITTANCE BREAKDOWN',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                              color: const Color(0xFFF37021),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '₦100 / ₦5k Transfer Fee',
                          style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              const Icon(Icons.shopping_bag_outlined, size: 14, color: Color(0xFF64748B)),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text('Gross Cash Collected', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)), overflow: TextOverflow.ellipsis),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(CurrencyFormatter.formatNaira(enteredCash), style: GoogleFonts.jetBrainsMono(fontSize: 12.5, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              const Icon(Icons.percent_rounded, size: 14, color: Color(0xFF16A34A)),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text('Less: Commission Retained', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)), overflow: TextOverflow.ellipsis),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('-${CurrencyFormatter.formatNaira(commissionRate)}', style: GoogleFonts.jetBrainsMono(fontSize: 12.5, fontWeight: FontWeight.bold, color: const Color(0xFF16A34A))),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              const Icon(Icons.local_shipping_outlined, size: 14, color: Color(0xFF00A2D3)),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text('Less: Fuel/Transport Retained', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)), overflow: TextOverflow.ellipsis),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('-${CurrencyFormatter.formatNaira(transportAllowance)}', style: GoogleFonts.jetBrainsMono(fontSize: 12.5, fontWeight: FontWeight.bold, color: const Color(0xFF00A2D3))),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              const Icon(Icons.receipt_outlined, size: 14, color: Color(0xFFF59E0B)),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text('Less: Transfer Fee (Dynamic)', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)), overflow: TextOverflow.ellipsis),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('-${CurrencyFormatter.formatNaira(cashTransferFee)}', style: GoogleFonts.jetBrainsMono(fontSize: 12.5, fontWeight: FontWeight.bold, color: const Color(0xFFF59E0B))),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Divider(height: 1),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF37021).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'NET CASH TO REMIT TO DC',
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFFC2410C),
                                  ),
                                ),
                                Text(
                                  'You retain ${CurrencyFormatter.formatNaira(totalRetainedByRider)} in earnings & fees',
                                  style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF9A3412)),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            CurrencyFormatter.formatNaira(netCashRemittance),
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFFC2410C),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

            // Digital Signature Section (Tappable Modal Signature Pad)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Proof of Delivery (POD) Signature',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: theme.colorScheme.onSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (podState.signatureBytes != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF86EFAC)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_circle_rounded, size: 12, color: Color(0xFF16A34A)),
                        const SizedBox(width: 4),
                        Text(
                          'Signed ✓',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF15803D),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () async {
                final result = await SignaturePadModal.show(
                  context: context,
                  orderId: order.orderNumber,
                  customerName: order.customerName,
                );
                if (result != null) {
                  ref.read(confirmDeliveryPodProvider.notifier).setSignature(result.pngBytes, result.signatureUrl);
                }
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: podState.signatureBytes != null
                        ? const Color(0xFF10B981)
                        : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                    width: podState.signatureBytes != null ? 1.5 : 1,
                  ),
                ),
                child: podState.signatureBytes != null
                    ? Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(
                              podState.signatureBytes!,
                              height: 85,
                              fit: BoxFit.contain,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.edit_outlined, size: 14, color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF00A2D3)),
                              const SizedBox(width: 4),
                              Text(
                                'Tap to Re-sign or Change',
                                style: GoogleFonts.inter(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF00A2D3),
                                ),
                              ),
                            ],
                          ),
                        ],
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.orange.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.draw_rounded, color: AppColors.orange, size: 24),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tap here to sign POD',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Opens isolated signature pad with smooth touch ink',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 14),

            // Optional Photo Proof / Waybill Snapshot Card
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'DELIVERY PHOTO PROOF / WAYBILL',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF64748B),
                      letterSpacing: 0.5,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (podState.photoBytes != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF86EFAC)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_circle_rounded, size: 12, color: Color(0xFF16A34A)),
                        const SizedBox(width: 4),
                        Text(
                          'Photo Attached ✓',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF15803D),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _pickOrCapturePhotoProof,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: podState.photoBytes != null
                        ? const Color(0xFF10B981)
                        : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                    width: podState.photoBytes != null ? 1.5 : 1,
                  ),
                ),
                child: podState.photoBytes != null
                    ? Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(
                              podState.photoBytes!,
                              height: 120,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.photo_camera_rounded, size: 14, color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF00A2D3)),
                              const SizedBox(width: 4),
                              Text(
                                'Tap to Retake / Replace Photo',
                                style: GoogleFonts.inter(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF00A2D3),
                                ),
                              ),
                            ],
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0284C7).withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.add_a_photo_outlined, color: Color(0xFF0284C7), size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Attach Parcel / Waybill Photo',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Snapshot of delivered package at doorstep or physical waybill',
                                  style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 16),

            // Real-time GPS Location Presence Proof Badge
            Consumer(
              builder: (context, ref, _) {
                final riderLoc = ref.watch(riderLocationProvider);
                final isDarkTheme = theme.brightness == Brightness.dark;
                return Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDarkTheme ? const Color(0xFF064E3B).withValues(alpha: 0.3) : const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF10B981).withValues(alpha: isDarkTheme ? 0.4 : 0.6),
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.18),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.gps_fixed_rounded,
                          color: Color(0xFF10B981),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'GPS PRESENCE PROOF CAPTURED',
                                    style: GoogleFonts.jetBrainsMono(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF059669),
                                      letterSpacing: 0.5,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981).withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'AUTO-CAPTURED',
                                    style: GoogleFonts.jetBrainsMono(
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF059669),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${riderLoc.latitude.toStringAsFixed(5)}°, ${riderLoc.longitude.toStringAsFixed(5)}° (±${riderLoc.accuracyMeters.toStringAsFixed(1)}m)',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: isDarkTheme ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B),
                              ),
                            ),
                            Text(
                              'Your exact coordinates are recorded to database as physical proof of presence at customer location.',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDarkTheme ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

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
                value: podState.hasConfirmedReceipt,
                onChanged: (val) {
                  if (val != null) ref.read(confirmDeliveryPodProvider.notifier).setConfirmedReceipt(val);
                },
              ),
            ),
            const SizedBox(height: 20),

            // Single Main Action Button (Confirm Cash Collection & POD)
            (() {
              final isButtonDisabled = podState.isLoading || !podState.hasConfirmedReceipt;
              return SizedBox(
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
                  onPressed: isButtonDisabled ? null : _submitDelivery,
                  icon: podState.isLoading
                      ? const SizedBox.shrink()
                      : const Icon(Icons.task_alt_rounded, size: 20),
                  label: podState.isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text(
                          'Confirm Cash Collection & POD',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                ),
              );
            }()),
          ],
        ),
      ),
    );
  }
}
