import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/helpers/formatters.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_logo_widget.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../stock/presentation/providers/stock_provider.dart';
import '../../domain/entities/order.dart';
import '../providers/orders_provider.dart';
import '../widgets/pda_navigation_card.dart';
import '../widgets/reschedule_callback_modal.dart';
import '../widgets/upsell_selector_modal.dart';

class OrderDetailPage extends ConsumerWidget {
  final String orderId;

  const OrderDetailPage({
    super.key,
    required this.orderId,
  });

  void _callCustomer(String phone) async {
    final cleanPhone = phone.replaceAll(' ', '').trim();
    if (cleanPhone.isEmpty) return;
    final uri = Uri.parse('tel:$cleanPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _openMap(OrderEntity order) async {
    final navUri = order.googleMapsNavUri;
    final webUri = order.googleMapsWebDirectionsUri;
    try {
      if (await canLaunchUrl(navUri)) {
        await launchUrl(navUri, mode: LaunchMode.externalApplication);
      } else if (await canLaunchUrl(webUri)) {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      try {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      } catch (_) {}
    }
  }

  void _openWhatsAppPrompt(OrderEntity order, WidgetRef ref) async {
    final authState = ref.read(authProvider);
    final user = authState.user;
    final riderName = user != null && (user.firstName.isNotEmpty || user.lastName.isNotEmpty)
        ? '${user.firstName} ${user.lastName}'.trim()
        : (user?.fullName.isNotEmpty == true ? user!.fullName : 'Dispatch Rider');

    final uri = order.getWhatsAppLocationRequestUri(riderName: riderName);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _startDelivery(BuildContext context, WidgetRef ref, OrderEntity order) async {
    // 1. Stock Inventory Pre-Validation Check matching Rule BR-004
    final stockItems = ref.read(stockProvider).stockItems;
    final String prodName = order.productName.toLowerCase();
    
    final matchingStock = stockItems.where((item) {
      final name = item.name.toLowerCase();
      return name.contains(prodName) || prodName.contains(name);
    }).toList();

    final int availableInCustody = matchingStock.isNotEmpty
        ? matchingStock.fold(0, (acc, item) => acc + item.availableCount)
        : 0;

    final int requiredQty = order.totalPhysicalQuantity > 0 ? order.totalPhysicalQuantity : 1;

    if (availableInCustody < requiredQty) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 26),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Insufficient Stock Custody',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'You currently have $availableInCustody available units of "${order.productName}" in your vehicle inventory custody (Required: $requiredQty).',
                style: const TextStyle(fontSize: 13.5, height: 1.4),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: const Text(
                  '⚠️ Business Rule BR-004: Riders cannot start out-for-delivery transit without physical inventory in hand.',
                  style: TextStyle(fontSize: 11.5, color: Color(0xFFB91C1C), fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.orange,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(ctx);
                context.push('/stock/request');
              },
              icon: const Icon(Icons.inventory_2_outlined, size: 16),
              label: const Text('Request Stock Transfer'),
            ),
          ],
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.primary,
        content: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Text('Starting delivery for ${order.orderNumber}...'),
          ],
        ),
        duration: const Duration(seconds: 1),
      ),
    );

    await ref.read(ordersProvider.notifier).updateOrderStatus(
          order.id,
          'in_transit',
          notes: 'Agent started delivery transit.',
        );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.orange,
          content: Text('Order is now Out for Delivery! 🚚'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final ordersState = ref.watch(ordersProvider);

    OrderEntity? matchedOrder;
    for (final o in ordersState.orders) {
      if (o.id == orderId || o.orderNumber == orderId) {
        matchedOrder = o;
        break;
      }
    }

    final order = matchedOrder ??
        (ordersState.orders.isNotEmpty
            ? ordersState.orders.first
            : OrderEntity(
                id: orderId,
                orderNumber: 'NX-849201',
                customerName: 'Chinedu Okafor',
                customerPhone: '+2348031234567',
                customerAltPhone: '+2348099887766',
                deliveryState: 'Lagos',
                deliveryCity: 'Lekki Phase 1',
                deliveryAddress: '12 Admiralty Way, Lekki Phase 1, Lagos',
                status: 'in_transit',
                quantity: 2,
                paidQuantity: 2,
                freeQuantity: 0,
                basePrice: 25000.0,
                upsellAmount: 2000.0,
                totalAmount: 52000.0,
                paymentType: 'pay_on_delivery',
                paymentStatus: 'pending',
                fulfillmentType: 'distributed_inventory',
                clientName: 'Novacare Limited',
                clientDeliveryFee: 5000.0,
                agentEntitlement: 2500.0,
                deliveryNotes: 'Call 10 minutes before arrival.',
                createdAt: DateTime.now(),
              ));

    // Dynamic Status Badge Colors & Labels
    Color statusBg;
    Color statusTextColor;
    String statusLabel;
    IconData statusIcon;

    switch (order.status) {
      case 'delivered':
        statusBg = const Color(0xFFDCFCE7);
        statusTextColor = const Color(0xFF15803D);
        statusLabel = 'DELIVERED & VERIFIED';
        statusIcon = Icons.check_circle_outline_rounded;
        break;
      case 'in_transit':
        statusBg = const Color(0xFFE0F2FE);
        statusTextColor = const Color(0xFF0369A1);
        statusLabel = 'OUT FOR DELIVERY';
        statusIcon = Icons.local_shipping_outlined;
        break;
      case 'failed':
        statusBg = const Color(0xFFFEE2E2);
        statusTextColor = const Color(0xFFB91C1C);
        statusLabel = 'DELIVERY FAILED';
        statusIcon = Icons.error_outline_rounded;
        break;
      case 'call_back':
        statusBg = const Color(0xFFFEF3C7);
        statusTextColor = const Color(0xFFD97706);
        statusLabel = 'CALL BACK REQUESTED';
        statusIcon = Icons.phone_callback_rounded;
        break;
      case 'accepted':
      case 'pending':
      default:
        statusBg = const Color(0xFFFDECDD);
        statusTextColor = const Color(0xFFB45309);
        statusLabel = 'PENDING (READY AT DC)';
        statusIcon = Icons.inventory_2_outlined;
        break;
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
          'ORDER DETAILS',
          style: GoogleFonts.inter(
            color: theme.colorScheme.onSurface,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.1,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: theme.colorScheme.onSurface),
            onPressed: () => ref.read(ordersProvider.notifier).fetchOrders(),
          ),
          const Padding(
            padding: EdgeInsets.only(right: 16),
            child: AppLogoWidget(
              variant: AppLogoVariant.landscape,
              height: 22,
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Hero Card: Tracking Number & Dynamic Status Badge
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.15)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'TRACKING ID',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurfaceVariant,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          order.orderNumber,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: theme.colorScheme.onSurface,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.access_time_rounded, size: 14, color: theme.colorScheme.onSurfaceVariant),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                DateTimeFormatter.formatDate(order.createdAt),
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: statusBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, color: statusTextColor, size: 14),
                        const SizedBox(width: 6),
                        Text(
                          statusLabel,
                          style: GoogleFonts.inter(
                            color: statusTextColor,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // 2. Dynamic Journey Stepper
            _DeliveryProgressTracker(status: order.status),
            const SizedBox(height: 14),

            // 3. Dynamic Contextual Alert Banner
            if (order.status == 'in_transit') ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.orange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.orange.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.navigation_outlined, color: AppColors.orange, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Out for Delivery with PDA. Hand over package to customer and collect POD payment.',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ] else if (order.status == 'delivered') ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF86EFAC)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.verified_rounded, color: Color(0xFF15803D), size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Delivery completed and confirmed! Funds logged to your outstanding collection ledger.',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF15803D),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ] else if (order.status == 'failed' || order.status == 'call_back') ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Color(0xFFB91C1C), size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Delivery Failed / Rescheduled: ${order.deliveryNotes ?? "Customer unreachable"}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFB91C1C),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // 4. Customer & Location Card with Interactive Actions
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
                      Row(
                        children: [
                          Icon(Icons.person_outline_rounded, color: theme.colorScheme.onSurfaceVariant, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Customer Information',
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          IconButton.filled(
                            style: IconButton.styleFrom(
                              backgroundColor: const Color(0xFF25D366),
                              foregroundColor: Colors.white,
                            ),
                            icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                            tooltip: 'WhatsApp Live Pin Request',
                            onPressed: () => _openWhatsAppPrompt(order, ref),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filled(
                            style: IconButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                            ),
                            icon: const Icon(Icons.call_rounded, size: 18),
                            tooltip: 'Call Customer',
                            onPressed: () => _callCustomer(order.customerPhone),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    order.customerName,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Phone: ${order.customerPhone}',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 13,
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (order.customerAltPhone != null && order.customerAltPhone!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Alt Phone: ${order.customerAltPhone}',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),

            // 5. GPS Navigation, Geocoding Confidence & WhatsApp Live PIN Radar Card
            PdaNavigationCard(order: order),
            const SizedBox(height: 14),

            // 5. Package & Fulfillment Details Card
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
                      Expanded(
                        child: Row(
                          children: [
                            Icon(Icons.inventory_2_outlined, color: theme.colorScheme.onSurfaceVariant, size: 20),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'Package Details',
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onSurface,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: order.isClientPackage
                              ? const Color(0xFF7A40B8).withValues(alpha: 0.12)
                              : const Color(0xFF008844).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          order.isClientPackage ? 'CLIENT PACKAGE' : 'DIST INVENTORY',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: order.isClientPackage ? const Color(0xFF7A40B8) : const Color(0xFF008844),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Client / Merchant:', style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          order.clientName,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Divider(height: 1),
                  const SizedBox(height: 10),

                  // Dynamic Item Breakdown Tile
                  _ItemBreakdownTile(
                    title: order.productName,
                    paidQty: order.paidQuantity,
                    freeQty: order.freeQuantity,
                    totalQty: order.totalPhysicalQuantity,
                  ),
                  const SizedBox(height: 8),

                  // + Add Upsell Item Action
                  if (order.status != 'delivered' && order.status != 'cancelled')
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF059669),
                        side: const BorderSide(color: Color(0xFF10B981)),
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () {
                        final stockItems = ref.read(stockProvider).stockItems;
                        UpsellSelectorModal.show(
                          context: context,
                          availableStock: stockItems,
                          onUpsellSelected: (item, extraPrice) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: const Color(0xFF16A34A),
                                content: Text('Added +1 ${item.name} (+${CurrencyFormatter.formatNaira(extraPrice)}) to order! 💰'),
                              ),
                            );
                          },
                        );
                      },
                      icon: const Icon(Icons.add_circle_outline_rounded, size: 16),
                      label: Text(
                        '+ Add On-Site Upsell (+₦1,500 Commission)',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),

                  if (order.deliveryNotes != null && order.deliveryNotes!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'OPERATIONAL NOTES / INSTRUCTIONS',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            order.deliveryNotes!,
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),

            // 6. Payment Collection & Financial Entitlements Card
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
                      Expanded(
                        child: Row(
                          children: [
                            Icon(Icons.payments_outlined, color: theme.colorScheme.onSurfaceVariant, size: 20),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'Payment & Entitlements',
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onSurface,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: order.isPod ? AppColors.orange : const Color(0xFF008844),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          order.isPod ? 'PAY ON DELIVERY' : 'PREPAID',
                          style: GoogleFonts.jetBrainsMono(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          order.isPod ? 'Amount to Collect from Customer' : 'Prepaid Order Value',
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
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: order.isPod ? AppColors.orange : const Color(0xFF008844),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text('Client Delivery Charge:', style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        CurrencyFormatter.formatNaira(order.clientDeliveryFee),
                        style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text('Agent Entitlement (Accrued Fee):', style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        CurrencyFormatter.formatNaira(order.agentEntitlement),
                        style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF00522A)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 7. Dynamic Contextual Action Buttons (Strictly tailored to status)
            if (order.status == 'accepted' || order.status == 'pending' || order.status == 'assigned') ...[
              // Context: Ready for departure / intake
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.orange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () => _startDelivery(context, ref, order),
                  icon: const Icon(Icons.navigation_outlined, size: 20),
                  label: const Text(
                    'START DELIVERY JOURNEY',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 0.5),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFEA580C),
                        side: const BorderSide(color: Color(0xFFEA580C), width: 1.2),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        final authState = ref.read(authProvider);
                        final agentId = authState.user?.deliveryAgentId ?? authState.user?.id ?? 'default-agent-id';
                        RescheduleCallbackModal.show(
                          context: context,
                          orderId: order.id,
                          customerName: order.customerName,
                          onRescheduleConfirmed: (dateTime, note) async {
                            await ref.read(ordersProvider.notifier).logDeliveryFailure(
                              orderId: order.id,
                              agentId: agentId,
                              reasonCode: 'rescheduled',
                              notes: note,
                              scheduledCallbackAt: dateTime.toIso8601String(),
                            );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: const Color(0xFFEA580C),
                                  content: Text('Order rescheduled for ${dateTime.day}/${dateTime.month}! 📅'),
                                ),
                              );
                            }
                          },
                        );
                      },
                      icon: const Icon(Icons.edit_calendar_rounded, size: 18),
                      label: const Text(
                        'Reschedule',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFBA1A1A),
                        side: const BorderSide(color: Color(0xFFBA1A1A), width: 1.2),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => context.push('/orders/${order.id}/log-failure'),
                      icon: const Icon(Icons.report_outlined, size: 18),
                      label: const Text(
                        'Report Failed',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => _callCustomer(order.customerPhone),
                      icon: const Icon(Icons.phone_outlined, size: 18),
                      label: const Text('Call Customer', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => _openMap(order),
                      icon: const Icon(Icons.map_outlined, size: 18),
                      label: const Text('Directions', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ] else if (order.status == 'in_transit') ...[
              // Context: En route / at customer location
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
                    elevation: 0,
                  ),
                  onPressed: () => context.push('/orders/${order.id}/deliver-pod'),
                  icon: const Icon(Icons.check_circle_outline_rounded, size: 20),
                  label: const Text(
                    'LOG DELIVERY SUCCESS (CONFIRM POD)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 0.4),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFEA580C),
                        side: const BorderSide(color: Color(0xFFEA580C), width: 1.2),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => context.push('/orders/${order.id}/log-failure'),
                      icon: const Icon(Icons.report_outlined, size: 18),
                      label: const Text(
                        'Report Issue',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => _callCustomer(order.customerPhone),
                      icon: const Icon(Icons.phone_outlined, size: 18),
                      label: const Text('Call Customer', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => _openMap(order),
                  icon: const Icon(Icons.navigation_outlined, size: 18),
                  label: const Text('Navigate GPS', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ] else if (order.status == 'delivered') ...[
              // Context: Delivered and closed
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.arrow_back_rounded, size: 18),
                  label: const Text(
                    'RETURN TO DELIVERIES LIST',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ),
            ] else if (order.status == 'failed' || order.status == 'call_back') ...[
              // Context: Failed or callback
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.orange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  onPressed: () => _startDelivery(context, ref, order),
                  icon: const Icon(Icons.replay_rounded, size: 20),
                  label: const Text(
                    'RE-ATTEMPT DELIVERY',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.colorScheme.onSurface,
                    side: BorderSide(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.arrow_back_rounded, size: 18),
                  label: const Text(
                    'RETURN TO DELIVERIES LIST',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _DeliveryProgressTracker extends StatelessWidget {
  final String status;

  const _DeliveryProgressTracker({required this.status});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    int currentStep = 0;
    if (status == 'accepted' || status == 'pending') {
      currentStep = 0;
    } else if (status == 'in_transit') {
      currentStep = 1;
    } else if (status == 'delivered') {
      currentStep = 2;
    } else if (status == 'failed' || status == 'call_back') {
      currentStep = 1;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
              Expanded(
                child: Text(
                  'DELIVERY JOURNEY',
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurfaceVariant,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  status == 'delivered'
                      ? '100% Completed'
                      : status == 'in_transit'
                          ? 'In Transit (Step 2 of 3)'
                          : 'Ready for Dispatch',
                  textAlign: TextAlign.end,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: status == 'delivered' ? const Color(0xFF008844) : AppColors.orange,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _buildStepNode(context, 'DC Picked', 0, currentStep, Icons.warehouse_outlined),
              _buildStepLine(0 < currentStep || status == 'delivered'),
              _buildStepNode(context, 'In Transit', 1, currentStep, Icons.local_shipping_outlined),
              _buildStepLine(1 < currentStep || status == 'delivered'),
              _buildStepNode(context, 'Delivered POD', 2, currentStep, Icons.check_circle_outline_rounded),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepNode(BuildContext context, String label, int stepIndex, int currentStep, IconData icon) {
    final isDone = (stepIndex < currentStep) || (stepIndex == 2 && status == 'delivered');
    final isCurrent = stepIndex == currentStep && status != 'delivered';
    final theme = Theme.of(context);

    Color bg;
    Color iconColor;
    if (isDone) {
      bg = const Color(0xFF008844);
      iconColor = Colors.white;
    } else if (isCurrent) {
      bg = AppColors.orange;
      iconColor = Colors.white;
    } else {
      bg = theme.colorScheme.surfaceContainer;
      iconColor = theme.colorScheme.onSurfaceVariant;
    }

    return Expanded(
      child: Column(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: bg,
              shape: BoxShape.circle,
              boxShadow: isCurrent
                  ? [
                      BoxShadow(
                        color: AppColors.orange.withValues(alpha: 0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      )
                    ]
                  : null,
            ),
            child: Icon(
              isDone ? Icons.check_rounded : icon,
              size: 16,
              color: iconColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isCurrent || isDone ? FontWeight.bold : FontWeight.normal,
              color: isCurrent || isDone ? theme.colorScheme.onSurface : theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildStepLine(bool isDone) {
    return Container(
      width: 24,
      height: 2,
      margin: const EdgeInsets.only(bottom: 18),
      color: isDone ? const Color(0xFF008844) : const Color(0xFFCBD5E1),
    );
  }
}

class _ItemBreakdownTile extends StatelessWidget {
  final String title;
  final int paidQty;
  final int freeQty;
  final int totalQty;

  const _ItemBreakdownTile({
    required this.title,
    required this.paidQty,
    required this.freeQty,
    required this.totalQty,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'PAID: $paidQty UNITS',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              if (freeQty > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.orange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'FREE PROMO: +$freeQty',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.orange,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              Text(
                'Total: $totalQty Pcs',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
