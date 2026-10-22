import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/widgets/user_avatar_widget.dart';
import '../../../orders/domain/entities/order.dart';
import '../providers/sales_supervisor_provider.dart';
import 'client_order_tracking_modal.dart';

class SuperviseeDetailModal extends StatefulWidget {
  final SuperviseePerformance performance;
  final bool isDark;

  const SuperviseeDetailModal({
    super.key,
    required this.performance,
    required this.isDark,
  });

  static Future<void> show(
    BuildContext context, {
    required SuperviseePerformance performance,
    required bool isDark,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => SuperviseeDetailModal(
        performance: performance,
        isDark: isDark,
      ),
    );
  }

  @override
  State<SuperviseeDetailModal> createState() => _SuperviseeDetailModalState();
}

class _SuperviseeDetailModalState extends State<SuperviseeDetailModal> {
  final _currency = NumberFormat.currency(symbol: "₦", decimalDigits: 0);
  String _orderFilter = 'all';

  @override
  Widget build(BuildContext context) {
    final closer = widget.performance.closer;
    final isDark = widget.isDark;
    final orders = widget.performance.orders;

    List<OrderEntity> filteredOrders = orders;
    if (_orderFilter == 'delivered') {
      filteredOrders = orders.where((o) => o.status.toLowerCase() == 'delivered').toList();
    } else if (_orderFilter == 'in_transit') {
      filteredOrders = orders.where((o) => o.status.toLowerCase().contains('transit') || o.status.toLowerCase().contains('dispatched')).toList();
    } else if (_orderFilter == 'pending') {
      filteredOrders = orders.where((o) => o.status.toLowerCase().contains('pending') || o.status.toLowerCase().contains('created')).toList();
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 680),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with Avatar & Details
            Row(
              children: [
                UserAvatarWidget(fullName: closer.fullName, radius: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              closer.fullName,
                              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF37021).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              closer.closerCode,
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFFF37021),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "${closer.phone.isNotEmpty ? closer.phone : 'No Phone'} • ${closer.email.isNotEmpty ? closer.email : 'No Email'}",
                        style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Quick Call & WhatsApp
                if (closer.phone.isNotEmpty) ...[
                  IconButton(
                    icon: const Icon(Icons.phone_rounded, color: Color(0xFF10B981), size: 20),
                    tooltip: 'Call Rep',
                    onPressed: () => launchUrl(Uri.parse('tel:${closer.phone}')),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chat_rounded, color: Color(0xFF2563EB), size: 20),
                    tooltip: 'WhatsApp Rep',
                    onPressed: () => launchUrl(Uri.parse('https://wa.me/234${closer.phone.replaceAll(RegExp(r"[^0-9]"), "")}')),
                  ),
                ],
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Performance Metrics Strip
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  _buildMetricCell('Closed Orders', '${widget.performance.totalOrders}', const Color(0xFF2563EB), isDark),
                  _buildDivider(isDark),
                  _buildMetricCell('Revenue', _currency.format(widget.performance.totalRevenue), const Color(0xFF10B981), isDark),
                  _buildDivider(isDark),
                  _buildMetricCell('Conversion', '${widget.performance.conversionRate.toStringAsFixed(1)}%', const Color(0xFFF37021), isDark),
                  _buildDivider(isDark),
                  _buildMetricCell('UPGs', '${widget.performance.approvedUpgCount}', const Color(0xFF8B5CF6), isDark),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Order History Header & Filter Pills
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Order History (${orders.length})",
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                Text(
                  "Tap order for full details",
                  style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF64748B)),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Filter Pills
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterPill('All (${orders.length})', 'all', isDark),
                  const SizedBox(width: 6),
                  _buildFilterPill('Delivered (${orders.where((o) => o.status.toLowerCase() == 'delivered').length})', 'delivered', isDark),
                  const SizedBox(width: 6),
                  _buildFilterPill('In-Transit (${orders.where((o) => o.status.toLowerCase().contains('transit')).length})', 'in_transit', isDark),
                  const SizedBox(width: 6),
                  _buildFilterPill('Pending (${orders.where((o) => o.status.toLowerCase().contains('pending')).length})', 'pending', isDark),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Orders List
            Expanded(
              child: filteredOrders.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.receipt_long_outlined, size: 40, color: Colors.grey),
                          const SizedBox(height: 8),
                          Text(
                            "No orders recorded for this rep yet.",
                            style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      itemCount: filteredOrders.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final order = filteredOrders[index];
                        final bool isDelivered = order.status.toLowerCase() == 'delivered';
                        final bool isUpgraded = order.upsellAmount > 0 || (order.deliveryNotes != null && order.deliveryNotes!.contains('UPG'));

                        return InkWell(
                          onTap: () => ClientOrderTrackingModal.show(context, order),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.all(11),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(7),
                                  decoration: BoxDecoration(
                                    color: (isDelivered ? const Color(0xFF10B981) : const Color(0xFF2563EB)).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    isDelivered ? Icons.check_circle_rounded : Icons.local_shipping_rounded,
                                    color: isDelivered ? const Color(0xFF10B981) : const Color(0xFF2563EB),
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            "#${order.orderNumber}",
                                            style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.bold),
                                          ),
                                          const SizedBox(width: 6),
                                          if (isUpgraded)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                "UPG",
                                                style: GoogleFonts.jetBrainsMono(
                                                  fontSize: 8.5,
                                                  fontWeight: FontWeight.bold,
                                                  color: const Color(0xFF10B981),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        "${order.customerName} • ${order.deliveryCity}",
                                        style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        "${order.productName} (${order.quantity} units)",
                                        style: GoogleFonts.inter(fontSize: 10.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      _currency.format(order.totalAmount),
                                      style: GoogleFonts.jetBrainsMono(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.bold,
                                        color: isDelivered ? const Color(0xFF10B981) : const Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: (isDelivered ? const Color(0xFF10B981) : const Color(0xFFF37021)).withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        order.status.toUpperCase(),
                                        style: GoogleFonts.jetBrainsMono(
                                          fontSize: 8.5,
                                          fontWeight: FontWeight.bold,
                                          color: isDelivered ? const Color(0xFF10B981) : const Color(0xFFF37021),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCell(String label, String value, Color color, bool isDark) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 9.5, color: const Color(0xFF64748B)), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.jetBrainsMono(fontSize: 12.5, fontWeight: FontWeight.bold, color: color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Container(
      width: 1,
      height: 28,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
    );
  }

  Widget _buildFilterPill(String title, String value, bool isDark) {
    final bool isSelected = _orderFilter == value;
    return GestureDetector(
      onTap: () => setState(() => _orderFilter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFF37021)
              : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }
}
