import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/helpers/formatters.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/order.dart';

class OrderCard extends StatelessWidget {
  final OrderEntity order;

  const OrderCard({super.key, required this.order});

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'assigned':
        return const Color(0xFF8B5CF6);
      case 'ready':
        return const Color(0xFF0D9488);
      case 'dispatch_assigned':
        return const Color(0xFF2563EB);
      case 'order_accepted':
      case 'accepted':
        return const Color(0xFF059669);
      case 'delivery_in_progress':
      case 'in_transit':
        return const Color(0xFFF37021);
      case 'rescheduled':
        return const Color(0xFFEA580C);
      case 'not_picking':
        return const Color(0xFFD97706);
      case 'call_back':
        return const Color(0xFFE11D48);
      case 'delivered':
      case 'completed':
        return const Color(0xFF00522A);
      case 'cancelled':
      case 'failed':
      case 'rejected':
      case 'not_ready':
        return const Color(0xFFBA1A1A);
      default:
        return AppColors.warning;
    }
  }

  String _formatStatus(String status) {
    return order.statusDisplay;
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(order.status);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => context.push('/orders/${order.id}'),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (order.isCallBackPendingOver4Hours) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFDC2626)),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '⚠️ CALL BACK PENDING (>4h) - Urgent action required',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFDC2626)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (order.isRescheduled) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEDD5),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFFED7AA)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.event_repeat_rounded, size: 14, color: Color(0xFFEA580C)),
                      const SizedBox(width: 5),
                      Text(
                        'Rescheduled: ',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFC2410C)),
                      ),
                    ],
                  ),
                ),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      order.orderNumber,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppColors.primary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      _formatStatus(order.status),
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.person_outline, size: 18, color: AppColors.textSecondaryDark),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      order.customerName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: AppColors.textPrimaryDark,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.location_on_outlined, size: 18, color: AppColors.textSecondaryDark),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      order.deliveryAddress,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondaryDark,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: order.isLocationVerified || order.locationConfidence == 'high'
                          ? const Color(0xFFDCFCE7)
                          : (order.locationConfidence == 'medium' ? const Color(0xFFFEF3C7) : const Color(0xFFFEE2E2)),
                    borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      order.isLocationVerified
                          ? 'GATE PIN'
                          : (order.locationConfidence == 'high' ? 'GPS PIN' : 'LANDMARK'),
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: order.isLocationVerified || order.locationConfidence == 'high'
                            ? const Color(0xFF15803D)
                            : (order.locationConfidence == 'medium' ? const Color(0xFFD97706) : const Color(0xFFB91C1C)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.inventory_2_outlined, size: 16, color: Color(0xFFF37021)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      order.packageDealName != null && order.packageDealName!.isNotEmpty
                          ? '${order.productName.isNotEmpty ? order.productName : "Product"} (${order.packageDealName})'
                          : '${order.productName.isNotEmpty ? order.productName : "Package"} (${order.quantity > 0 ? order.quantity : 1} units)',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimaryDark,
                      ),
                    ),
                  ),
                  if (order.upsellAmount > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                      ),
                      child: const Text(
                        'UPG ?',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF059669),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              const Divider(color: AppColors.cardDark, height: 1),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      order.isPod ? 'Pay on Delivery (POD)' : 'Prepaid',
                      style: TextStyle(
                        color: order.isPod ? AppColors.warning : AppColors.success,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    CurrencyFormatter.formatNaira(order.totalAmount),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppColors.textPrimaryDark,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
