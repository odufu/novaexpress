import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/helpers/map_launcher_helper.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/user_avatar_widget.dart';
import '../../../dc_console/domain/entities/dc_fleet_driver.dart';
import '../../../dc_console/domain/entities/distribution_center.dart';
import '../../../dc_console/presentation/providers/dc_console_provider.dart';
import '../../../orders/domain/entities/order.dart';
import '../../../orders/presentation/providers/orders_provider.dart';

class ClientOrderTrackingModal extends ConsumerWidget {
  final OrderEntity order;

  const ClientOrderTrackingModal({super.key, required this.order});

  static Future<void> show(BuildContext context, OrderEntity order) {
    return showDialog<void>(
      context: context,
      builder: (context) => ClientOrderTrackingModal(order: order),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Dynamically watch live order updates from ordersProvider
    final liveOrders = ref.watch(ordersProvider).orders;
    final currentOrder = liveOrders.firstWhere(
      (o) => o.id == order.id || o.orderNumber == order.orderNumber,
      orElse: () => order,
    );

    // Dynamically watch DC console state for driver and hub details
    final dcState = ref.watch(dcConsoleProvider);

    // Resolve assigned driver entity if assigned
    DCFleetDriver? assignedDriver;
    if (currentOrder.deliveryAgentId != null && currentOrder.deliveryAgentId!.isNotEmpty) {
      for (final d in dcState.drivers) {
        if (d.id == currentOrder.deliveryAgentId || d.driverCode == currentOrder.deliveryAgentCode) {
          assignedDriver = d;
          break;
        }
      }
    }
    // Fallback if driver info is recorded directly on the order
    if (assignedDriver == null && currentOrder.assignedAgentName != null && currentOrder.assignedAgentName!.isNotEmpty) {
      assignedDriver = DCFleetDriver(
        id: currentOrder.deliveryAgentId ?? 'pda-fallback',
        driverCode: currentOrder.deliveryAgentCode ?? 'PDA',
        name: currentOrder.assignedAgentName!,
        phone: currentOrder.assignedAgentPhone ?? '08012345678',
        avatarUrl: '',
        vehicleModel: 'Motorcycle',
        vehiclePlate: 'ABJ-894-XA',
        vehicleType: 'Motorcycle',
        status: 'active',
        assignedZone: currentOrder.deliveryCity,
        totalAssignedOrders: 0,
        completedOrders: 0,
        routeProgressPercent: 0,
        efficiencyRating: 100,
        cashInCustody: 0,
        itemsInCustody: 0,
      );
    }

    // Resolve Distribution Center hub
    DistributionCenter? matchedHub;
    if (currentOrder.distributionCenterId != null && currentOrder.distributionCenterId!.isNotEmpty) {
      for (final hub in dcState.distributionCenters) {
        if (hub.id == currentOrder.distributionCenterId || hub.name == currentOrder.distributionCenterName) {
          matchedHub = hub;
          break;
        }
      }
    }
    matchedHub ??= dcState.distributionCenters.isNotEmpty ? dcState.distributionCenters.first : null;

    final statusStr = currentOrder.status.toLowerCase();
    final isDelivered = currentOrder.isDelivered || statusStr == 'delivered' || statusStr == 'completed';
    final isInTransit = statusStr == 'in_transit' || statusStr == 'out_for_delivery' || statusStr == 'accepted';
    final isAssigned = statusStr == 'assigned' || isInTransit || isDelivered || assignedDriver != null;
    final isFailed = currentOrder.isFailed || statusStr == 'failed' || statusStr == 'cancelled' || statusStr == 'rejected';

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 840),
        child: Column(
          children: [
            // Modal Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
              decoration: const BoxDecoration(
                color: Color(0xFF0F172A),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D9488).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.track_changes_rounded, color: Color(0xFF2DD4BF), size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Order ${currentOrder.orderNumber}',
                              style: GoogleFonts.inter(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 8),
                            _buildStatusPill(currentOrder.status),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Created ${currentOrder.createdAt.toLocal().toString().substring(0, 16)} • ${currentOrder.deliveryCity}, ${currentOrder.deliveryState}',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8)),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Scrollable Body
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // Client-Focused Quick Metrics Row
                  _buildQuickMetrics(currentOrder, assignedDriver, matchedHub, isDark),

                  const SizedBox(height: 20),

                  // LIVE DELIVERY HANDLER & FOLLOWUP CARD (PROMINENT)
                  _buildLiveDeliveryHandlerCard(
                    context: context,
                    currentOrder: currentOrder,
                    assignedDriver: assignedDriver,
                    matchedHub: matchedHub,
                    isAssigned: isAssigned,
                    isInTransit: isInTransit,
                    isDelivered: isDelivered,
                    isDark: isDark,
                  ),

                  const SizedBox(height: 24),

                  // Fulfillment Timeline Journey
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'FULFILLMENT TIMELINE',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.1,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D9488).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.sync_rounded, size: 12, color: Color(0xFF0D9488)),
                            const SizedBox(width: 4),
                            Text(
                              'Live Sync',
                              style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w600, color: const Color(0xFF0D9488)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildTimelineStep(
                    icon: Icons.check_circle_rounded,
                    title: '1. Order Created & Commercial Package Reserved',
                    subtitle: 'Product: ${currentOrder.productName} (${currentOrder.packageDealName ?? "${currentOrder.quantity} units"})\nOrder Value: ₦${currentOrder.totalAmount.toStringAsFixed(0)}',
                    timestamp: currentOrder.createdAt.toLocal().toString().substring(0, 16),
                    isDone: true,
                    isCurrent: statusStr == 'created',
                  ),
                  _buildTimelineStep(
                    icon: Icons.store_mall_directory_rounded,
                    title: '2. Routed to Regional Distribution Center',
                    subtitle: 'Hub: ${matchedHub?.name ?? currentOrder.distributionCenterName ?? "Wuse Central Hub (DC-WUSE-01)"}\nDestination Zone: ${currentOrder.deliveryState} / ${currentOrder.deliveryLga ?? currentOrder.deliveryCity}',
                    timestamp: 'Matched via Automated State/LGA Dispatch',
                    isDone: currentOrder.distributionCenterId != null || matchedHub != null,
                    isCurrent: statusStr == 'pending_dispatch' || statusStr == 'pending_rider_assignment',
                  ),
                  _buildTimelineStep(
                    icon: Icons.two_wheeler_rounded,
                    title: '3. Assigned to Field Delivery Agent (PDA)',
                    subtitle: assignedDriver != null
                        ? 'Handler: ${assignedDriver.name} (${assignedDriver.driverCode})\nPhone: ${assignedDriver.phone} • Vehicle: ${assignedDriver.vehicleModel}'
                        : 'Awaiting rider allocation at ${matchedHub?.name ?? currentOrder.distributionCenterName ?? "Station DC"}',
                    timestamp: isInTransit ? 'Out for delivery' : (isAssigned ? 'Assigned' : 'Pending'),
                    isDone: isAssigned,
                    isCurrent: isInTransit,
                  ),
                  _buildTimelineStep(
                    icon: isFailed ? Icons.cancel_rounded : Icons.verified_rounded,
                    title: isFailed ? '4. Delivery Unsuccessful' : '4. Final Delivery & Payment Confirmed',
                    subtitle: isDelivered
                        ? 'Payment: ${currentOrder.paymentType.toUpperCase()} - Paid ₦${currentOrder.totalAmount.toStringAsFixed(0)}\nPOD Signature & Photo Confirmed'
                        : (isFailed ? 'Order failed delivery or cancelled' : 'Pending Customer Handover & Cash Collection'),
                    timestamp: isDelivered ? (currentOrder.deliveredAt?.toLocal().toString().substring(0, 16) ?? 'Completed') : 'Pending',
                    isDone: isDelivered,
                    isCurrent: isDelivered,
                    isFailed: isFailed,
                    isLast: true,
                  ),

                  const SizedBox(height: 20),
                  const Divider(color: Color(0xFFE2E8F0)),
                  const SizedBox(height: 16),

                  // Customer & Delivery Destination Card
                  _buildCustomerDestinationCard(context, currentOrder, isDark),

                  if (currentOrder.closerName != null && currentOrder.closerName!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildCloserCard(currentOrder, isDark),
                  ],
                ],
              ),
            ),

            // Modal Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF151D36) : const Color(0xFFF8FAFC),
                border: Border(top: BorderSide(color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFE2E8F0))),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.business_rounded, size: 16, color: Color(0xFF64748B)),
                      const SizedBox(width: 6),
                      Text(
                        'Client: ${currentOrder.clientCompany}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                        ),
                      ),
                    ],
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D9488),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close Tracking'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Quick Client-Focused Metrics Row
  Widget _buildQuickMetrics(OrderEntity order, DCFleetDriver? rider, DistributionCenter? hub, bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 580;
        final card1 = _buildMetricTile(
          icon: Icons.payments_outlined,
          iconColor: const Color(0xFF10B981),
          label: 'Total Order Value',
          value: '₦${order.totalAmount.toStringAsFixed(0)}',
          subtext: order.paymentType == 'prepaid' ? 'Prepaid (Direct Pay)' : 'Pay on Delivery (POS/Cash)',
          isDark: isDark,
        );

        final isSettled = order.remittanceStatus.toLowerCase() == 'cleared' ||
            order.remittanceStatus.toLowerCase() == 'prepaid' ||
            order.financialSettlementStatus.toLowerCase().contains('settled');

        final card2 = _buildMetricTile(
          icon: Icons.account_balance_wallet_outlined,
          iconColor: isSettled ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
          label: 'Remittance Status',
          value: isSettled ? 'Settled' : 'Pending Remittance',
          subtext: isSettled ? 'Funds cleared to wallet' : 'Settlement pending delivery',
          isDark: isDark,
        );

        final card3 = _buildMetricTile(
          icon: Icons.inventory_2_outlined,
          iconColor: const Color(0xFF3B82F6),
          label: 'Physical Product',
          value: '${order.quantity}x ${order.productName}',
          subtext: order.packageDealName ?? (order.freeQuantity > 0 ? '+ ${order.freeQuantity} Promo Bonus' : 'Standard SKU'),
          isDark: isDark,
        );

        final card4 = _buildMetricTile(
          icon: Icons.two_wheeler_outlined,
          iconColor: rider != null ? const Color(0xFF10B981) : const Color(0xFF8B5CF6),
          label: 'Custody Holder',
          value: rider != null ? rider.name : (hub?.name ?? 'Regional DC Hub'),
          subtext: rider != null ? 'In vehicle custody (${rider.driverCode})' : 'In hub dispatch queue',
          isDark: isDark,
        );

        if (isNarrow) {
          return Column(
            children: [
              Row(children: [Expanded(child: card1), const SizedBox(width: 8), Expanded(child: card2)]),
              const SizedBox(height: 8),
              Row(children: [Expanded(child: card3), const SizedBox(width: 8), Expanded(child: card4)]),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: card1),
            const SizedBox(width: 8),
            Expanded(child: card2),
            const SizedBox(width: 8),
            Expanded(child: card3),
            const SizedBox(width: 8),
            Expanded(child: card4),
          ],
        );
      },
    );
  }

  Widget _buildMetricTile({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required String subtext,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: iconColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 13.5,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            subtext,
            style: GoogleFonts.inter(
              fontSize: 10,
              color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // LIVE DELIVERY HANDLER & FOLLOWUP CARD (CLIENT CONTEXT)
  Widget _buildLiveDeliveryHandlerCard({
    required BuildContext context,
    required OrderEntity currentOrder,
    required DCFleetDriver? assignedDriver,
    required DistributionCenter? matchedHub,
    required bool isAssigned,
    required bool isInTransit,
    required bool isDelivered,
    required bool isDark,
  }) {
    if (assignedDriver != null) {
      // Rider Assigned View
      Color statusColor;
      String statusText;
      if (isDelivered) {
        statusColor = const Color(0xFF10B981);
        statusText = 'Delivered & Completed';
      } else if (isInTransit) {
        statusColor = const Color(0xFF0D9488);
        statusText = 'Active on Delivery Route';
      } else {
        statusColor = const Color(0xFFF59E0B);
        statusText = 'Dispatched to Rider';
      }

      return Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isInTransit ? const Color(0xFF0D9488) : (isDark ? const Color(0xFF2E3D6B) : const Color(0xFFE2E8F0)),
            width: isInTransit ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: (isInTransit ? const Color(0xFF0D9488) : Colors.black).withValues(alpha: isDark ? 0.2 : 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF151D36) : const Color(0xFFF1F5F9),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(11),
                  topRight: Radius.circular(11),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.two_wheeler_rounded, size: 18, color: Color(0xFF0D9488)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'LIVE DELIVERY HANDLER (RIDER)',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Live Status Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(shape: BoxShape.circle, color: statusColor),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          statusText,
                          style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Body Info
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      UserAvatarWidget(
                        avatarUrl: assignedDriver.avatarUrl,
                        fullName: assignedDriver.name,
                        radius: 24,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  assignedDriver.name,
                                  style: GoogleFonts.inter(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    assignedDriver.driverCode,
                                    style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF2563EB)),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    assignedDriver.isPda ? 'PDA Rider' : 'Express Courier',
                                    style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF10B981)),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${assignedDriver.vehicleModel} (${assignedDriver.vehiclePlate}) • Operating Zone: ${assignedDriver.assignedZone}',
                              style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                const Icon(Icons.phone_outlined, size: 13, color: Color(0xFF0D9488)),
                                const SizedBox(width: 4),
                                Text(
                                  assignedDriver.phone,
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white70 : const Color(0xFF334155),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),
                  const Divider(color: Color(0xFFE2E8F0), height: 1),
                  const SizedBox(height: 12),

                  // Direct Follow-up Action Buttons
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    alignment: WrapAlignment.start,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      // 1. Call Handler
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0D9488),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.phone_rounded, size: 14),
                        label: const Text('Call Handler', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        onPressed: () {
                          MapLauncherHelper.launchPhoneCall(context: context, phoneNumber: assignedDriver.phone);
                        },
                      ),

                      // 2. WhatsApp Followup
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF25D366),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.chat_rounded, size: 14),
                        label: const Text('WhatsApp Followup', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        onPressed: () {
                          final msg =
                              'Hello ${assignedDriver.name}, checking in from ${currentOrder.clientCompany} regarding delivery of order #${currentOrder.orderNumber} for ${currentOrder.customerName} (${currentOrder.deliveryAddress}). Please provide a delivery ETA update.';
                          MapLauncherHelper.launchWhatsApp(context: context, customerPhone: assignedDriver.phone, message: msg);
                        },
                      ),

                      // 3. Copy Phone Number
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          side: BorderSide(color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.copy_rounded, size: 13, color: Color(0xFF64748B)),
                        label: Text(
                          'Copy Contact',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                          ),
                        ),
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(text: assignedDriver.phone));
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Rider contact (${assignedDriver.phone}) copied to clipboard! 📋'),
                                backgroundColor: const Color(0xFF0D9488),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    } else {
      // Unassigned / Hub Dispatch Queue View
      final hubName = matchedHub?.name ?? currentOrder.distributionCenterName ?? 'Wuse Central Distribution Hub';
      final hubPhone = matchedHub?.contactPhone ?? '+234 802 345 6789';
      final hubManager = matchedHub?.managerName ?? 'Adekunle Supervisor';

      return Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(11),
                  topRight: Radius.circular(11),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warehouse_rounded, size: 18, color: Color(0xFFD97706)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'REGIONAL DISTRIBUTION CENTER & DISPATCH QUEUE',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                        color: const Color(0xFFD97706),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Awaiting Rider Assignment',
                      style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFFB45309)),
                    ),
                  ),
                ],
              ),
            ),

            // Body Info
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.store_mall_directory_rounded, color: Color(0xFFD97706), size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              hubName,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF1E293B),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Physical stock is reserved at regional DC station. Order is in queue for field PDA delivery agent assignment.',
                              style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Station Supervisor: $hubManager • Dispatch Phone: $hubPhone',
                              style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: const Color(0xFF0D9488)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(color: Color(0xFFE2E8F0), height: 1),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0D9488),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.phone_rounded, size: 14),
                        label: const Text('Call DC Station', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        onPressed: () {
                          MapLauncherHelper.launchPhoneCall(context: context, phoneNumber: hubPhone);
                        },
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF25D366),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.chat_rounded, size: 14),
                        label: const Text('WhatsApp Dispatch Desk', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        onPressed: () {
                          final msg =
                              'Hello $hubManager, checking in from ${currentOrder.clientCompany} regarding dispatch status for order #${currentOrder.orderNumber} to ${currentOrder.deliveryCity}. Could you please expedite rider allocation?';
                          MapLauncherHelper.launchWhatsApp(context: context, customerPhone: hubPhone, message: msg);
                        },
                      ),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          side: BorderSide(color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.copy_rounded, size: 13, color: Color(0xFF64748B)),
                        label: Text('Copy Station Contact', style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569))),
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(text: hubPhone));
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('DC Hub contact ($hubPhone) copied! 📋'),
                                backgroundColor: const Color(0xFF0D9488),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
  }

  // Customer & Delivery Destination Card
  Widget _buildCustomerDestinationCard(BuildContext context, OrderEntity order, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF151D36) : const Color(0xFFF1F5F9),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(11),
                topRight: Radius.circular(11),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.person_pin_circle_rounded, size: 18, color: Color(0xFF3B82F6)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'DESTINATION & CUSTOMER RECIPIENT',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildInfoRow(Icons.person_outline_rounded, 'Customer Name', order.customerName, isDark),
                const SizedBox(height: 8),
                _buildInfoRow(Icons.phone_outlined, 'Primary Phone', order.customerPhone, isDark),
                if (order.customerAltPhone != null && order.customerAltPhone!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _buildInfoRow(Icons.phone_android_outlined, 'Alt Phone', order.customerAltPhone!, isDark),
                ],
                const SizedBox(height: 8),
                _buildInfoRow(Icons.place_outlined, 'City / LGA & State', '${order.deliveryLga ?? order.deliveryCity}, ${order.deliveryState}', isDark),
                const SizedBox(height: 8),
                _buildInfoRow(Icons.home_outlined, 'Delivery Address', order.deliveryAddress, isDark),
                if (order.landmark != null && order.landmark!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _buildInfoRow(Icons.near_me_outlined, 'Landmark', order.landmark!, isDark),
                ],
                if (order.deliveryNotes != null && order.deliveryNotes!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _buildInfoRow(Icons.note_alt_outlined, 'Delivery Notes', order.deliveryNotes!, isDark),
                ],

                const SizedBox(height: 14),
                const Divider(color: Color(0xFFE2E8F0), height: 1),
                const SizedBox(height: 12),

                // Customer Action Followup Buttons
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        side: const BorderSide(color: Color(0xFF0D9488)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.phone_rounded, size: 14, color: Color(0xFF0D9488)),
                      label: const Text('Call Customer', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0D9488))),
                      onPressed: () {
                        MapLauncherHelper.launchPhoneCall(context: context, phoneNumber: order.customerPhone);
                      },
                    ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        side: const BorderSide(color: Color(0xFF25D366)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.chat_rounded, size: 14, color: Color(0xFF25D366)),
                      label: const Text('WhatsApp Customer', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF25D366))),
                      onPressed: () {
                        final msg =
                            'Hello ${order.customerName}, this is ${order.clientCompany} following up on your order #${order.orderNumber} for ${order.productName}. Our delivery agent is handling fulfillment to ${order.deliveryAddress}. Please let us know if your location or availability has changed.';
                        MapLauncherHelper.launchWhatsApp(context: context, customerPhone: order.customerPhone, message: msg);
                      },
                    ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        side: const BorderSide(color: Color(0xFF3B82F6)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.map_rounded, size: 14, color: Color(0xFF3B82F6)),
                      label: const Text('View on Map', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF3B82F6))),
                      onPressed: () {
                        MapLauncherHelper.launchTurnByTurnNavigation(
                          context: context,
                          destinationAddress: '${order.deliveryAddress}, ${order.deliveryCity}, ${order.deliveryState}',
                          customerName: order.customerName,
                          latitude: order.latitude,
                          longitude: order.longitude,
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Closer Attribution Card
  Widget _buildCloserCard(OrderEntity order, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          const Icon(Icons.support_agent_rounded, size: 18, color: Color(0xFF8B5CF6)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Sales Closer: ${order.closerName!} ${order.closerCode != null ? "(${order.closerCode})" : ""}',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : const Color(0xFF334155),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineStep({
    required IconData icon,
    required String title,
    required String subtitle,
    required String timestamp,
    required bool isDone,
    required bool isCurrent,
    bool isFailed = false,
    bool isLast = false,
  }) {
    final color = isFailed
        ? AppColors.danger
        : (isDone ? const Color(0xFF0D9488) : (isCurrent ? const Color(0xFF2563EB) : const Color(0xFF94A3B8)));

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 2),
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 48,
                color: isDone ? const Color(0xFF0D9488) : const Color(0xFFCBD5E1),
              ),
          ],
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                    ),
                    Text(
                      timestamp,
                      style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF475569), height: 1.3),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: const Color(0xFF64748B)),
        const SizedBox(width: 8),
        SizedBox(
          width: 140,
          child: Text(
            label,
            style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusPill(String status) {
    Color bg;
    Color fg;
    String text;

    final s = status.toLowerCase();
    if (s == 'delivered' || s == 'completed') {
      bg = const Color(0xFFDCFCE7);
      fg = const Color(0xFF166534);
      text = 'Delivered';
    } else if (s == 'in_transit' || s == 'out_for_delivery' || s == 'accepted') {
      bg = const Color(0xFFDBEAFE);
      fg = const Color(0xFF1E40AF);
      text = 'In Transit';
    } else if (s == 'assigned') {
      bg = const Color(0xFFFEF3C7);
      fg = const Color(0xFF92400E);
      text = 'Assigned';
    } else if (s == 'failed' || s == 'cancelled' || s == 'rejected') {
      bg = const Color(0xFFFEE2E2);
      fg = const Color(0xFF991B1B);
      text = 'Failed';
    } else {
      bg = const Color(0xFFF1F5F9);
      fg = const Color(0xFF475569);
      text = 'Processing';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }
}
