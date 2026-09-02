import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../orders/domain/entities/order.dart';

class ClientOrderTrackingModal extends StatelessWidget {
  final OrderEntity order;

  const ClientOrderTrackingModal({super.key, required this.order});

  static Future<void> show(BuildContext context, OrderEntity order) {
    return showDialog<void>(
      context: context,
      builder: (context) => ClientOrderTrackingModal(order: order),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDelivered = order.isDelivered;
    final statusStr = order.status.toLowerCase();
    final isInTransit = statusStr == 'in_transit' || statusStr == 'out_for_delivery' || statusStr == 'accepted';
    final isAssigned = statusStr == 'assigned' || isInTransit || isDelivered;
    final isFailed = order.isFailed;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 720),
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
                              'Order ${order.orderNumber}',
                              style: GoogleFonts.inter(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 8),
                            _buildStatusPill(order.status),
                          ],
                        ),
                        Text(
                          'Live Tracking & Real-Time Fulfillment Journey',
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

            // Scrollable Content
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  // Progress Stepper Journey
                  Text(
                    'FULFILLMENT TIMELINE',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildTimelineStep(
                    icon: Icons.check_circle_rounded,
                    title: '1. Order Created & Commercial Package Reserved',
                    subtitle: 'Product: ${order.productName} (${order.packageName ?? "${order.quantity} units"})\nOrder Value: ₦${order.totalAmount.toStringAsFixed(0)}',
                    timestamp: order.createdAt.toLocal().toString().substring(0, 16),
                    isDone: true,
                    isCurrent: statusStr == 'created',
                  ),
                  _buildTimelineStep(
                    icon: Icons.store_mall_directory_rounded,
                    title: '2. Routed to Regional Distribution Center',
                    subtitle: 'Hub: ${order.distributionCenterName ?? "Wuse Central Hub (DC-ABJ-01)"}\nDestination Zone: ${order.deliveryState} / ${order.deliveryLga ?? "AMAC"}',
                    timestamp: 'Matched via Automated State/LGA Dispatch',
                    isDone: order.distributionCenterId != null,
                    isCurrent: statusStr == 'pending_dispatch' || statusStr == 'pending_rider_assignment',
                  ),
                  _buildTimelineStep(
                    icon: Icons.two_wheeler_rounded,
                    title: '3. Assigned to Field Delivery Agent (PDA)',
                    subtitle: order.assignedAgentName != null
                        ? 'Rider: ${order.assignedAgentName}\nContact: ${order.assignedAgentPhone ?? "08012345678"}'
                        : 'Awaiting rider allocation at ${order.distributionCenterName ?? "Station DC"}',
                    timestamp: isAssigned ? 'Out for delivery' : 'Pending',
                    isDone: isAssigned,
                    isCurrent: isInTransit,
                  ),
                  _buildTimelineStep(
                    icon: isFailed ? Icons.cancel_rounded : Icons.verified_rounded,
                    title: isFailed ? '4. Delivery Unsuccessful' : '4. Final Delivery & Payment Confirmed',
                    subtitle: isDelivered
                        ? 'Payment: ${order.paymentType} - Paid ₦${order.totalAmount.toStringAsFixed(0)}\nPOD Signature & Photo Confirmed'
                        : (isFailed ? 'Order failed delivery or cancelled' : 'Pending Customer Handover'),
                    timestamp: isDelivered ? order.updatedAt?.toLocal().toString().substring(0, 16) ?? 'Completed' : 'Pending',
                    isDone: isDelivered,
                    isCurrent: isDelivered,
                    isFailed: isFailed,
                    isLast: true,
                  ),

                  const SizedBox(height: 20),
                  const Divider(color: Color(0xFFE2E8F0)),
                  const SizedBox(height: 16),

                  // Customer & Delivery Destination Card
                  Text(
                    'DESTINATION & RECIPIENT',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        _buildInfoRow(Icons.person_outline_rounded, 'Recipient', order.customerName),
                        const SizedBox(height: 8),
                        _buildInfoRow(Icons.phone_outlined, 'Phone', order.customerPhone),
                        if (order.customerAltPhone != null && order.customerAltPhone!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          _buildInfoRow(Icons.phone_android_outlined, 'Alt Phone', order.customerAltPhone!),
                        ],
                        const SizedBox(height: 8),
                        _buildInfoRow(Icons.place_outlined, 'Location', '${order.deliveryLga ?? "AMAC"}, ${order.deliveryState}'),
                        const SizedBox(height: 8),
                        _buildInfoRow(Icons.home_outlined, 'Address', order.deliveryAddress),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Assigned Logistics Assets
                  Text(
                    'ASSIGNED LOGISTICS ASSETS',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        _buildInfoRow(
                          Icons.warehouse_outlined,
                          'Distribution Center',
                          order.distributionCenterName ?? 'Wuse Central Distribution Hub',
                        ),
                        const SizedBox(height: 8),
                        _buildInfoRow(
                          Icons.sports_motorsports_outlined,
                          'Assigned Rider',
                          order.assignedAgentName ?? 'Pending Auto-Assignment',
                        ),
                        if (order.assignedAgentPhone != null) ...[
                          const SizedBox(height: 8),
                          _buildInfoRow(
                            Icons.contact_phone_outlined,
                            'Rider Phone',
                            order.assignedAgentPhone!,
                          ),
                        ],
                        const SizedBox(height: 8),
                        _buildInfoRow(
                          Icons.payment_outlined,
                          'Payment Status',
                          '${order.paymentType} (${order.paymentStatus.toUpperCase()})',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Client: ${order.clientName}',
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D9488),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
                height: 44,
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
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF475569)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: const Color(0xFF64748B)),
        const SizedBox(width: 8),
        SizedBox(
          width: 130,
          child: Text(
            label,
            style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B)),
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
