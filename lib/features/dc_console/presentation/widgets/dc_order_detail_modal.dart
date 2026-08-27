import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/helpers/formatters.dart';
import '../../../orders/domain/entities/order.dart';
import '../../../orders/presentation/providers/orders_provider.dart';
import '../../../stock/domain/entities/stock_item.dart';
import '../../../stock/presentation/providers/stock_provider.dart';
import '../../domain/entities/dc_fleet_driver.dart';
import '../providers/dc_console_provider.dart';

class DCOrderDetailModal extends ConsumerStatefulWidget {
  final OrderEntity order;

  const DCOrderDetailModal({super.key, required this.order});

  @override
  ConsumerState<DCOrderDetailModal> createState() => _DCOrderDetailModalState();
}

class _DCOrderDetailModalState extends ConsumerState<DCOrderDetailModal> {
  late OrderEntity _currentOrder;

  @override
  void initState() {
    super.initState();
    _currentOrder = widget.order;
  }

  Future<void> _launchUri(Uri uri) async {
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final dcState = ref.watch(dcConsoleProvider);
    final stockState = ref.watch(stockProvider);

    // Find linked warehouse stock item
    final targetStock = stockState.stockItems.firstWhere(
      (s) => s.name.toLowerCase().contains(_currentOrder.productName.toLowerCase()) ||
             _currentOrder.productName.toLowerCase().contains(s.name.toLowerCase()) ||
             (s.sku.isNotEmpty && _currentOrder.productSku != null && s.sku.toLowerCase() == _currentOrder.productSku!.toLowerCase()),
      orElse: () => stockState.stockItems.isNotEmpty
          ? stockState.stockItems.first
          : const StockItemEntity(id: '', sku: '', name: '', description: '', price: 0, assignedCount: 0, deliveredCount: 0, availableCount: 0, returnedCount: 0, category: ''),
    );

    // Find assigned driver entity if any
    DCFleetDriver? assignedDriver;
    if (_currentOrder.deliveryAgentId != null && _currentOrder.deliveryAgentId!.isNotEmpty) {
      assignedDriver = dcState.drivers.firstWhere(
        (d) => d.id == _currentOrder.deliveryAgentId || d.driverCode == _currentOrder.deliveryAgentCode,
        orElse: () => DCFleetDriver(
          id: _currentOrder.deliveryAgentId ?? '',
          name: _currentOrder.deliveryAgentName ?? 'Assigned Rider',
          phone: _currentOrder.deliveryAgentPhone ?? '+234 800 000 0000',
          driverCode: _currentOrder.deliveryAgentCode ?? 'PDA',
          avatarUrl: '',
          vehicleModel: 'Motorcycle',
          vehiclePlate: 'ABJ-894-XA',
          vehicleType: 'Motorcycle',
          status: 'active',
          assignedZone: _currentOrder.deliveryCity,
          totalAssignedOrders: 10,
          completedOrders: 8,
          routeProgressPercent: 80.0,
          efficiencyRating: 4.8,
          cashInCustody: 25000,
          itemsInCustody: 5,
        ),
      );
    }

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 780, maxHeight: 850),
        child: Column(
          children: [
            // 1. Header Banner
            _buildModalHeader(context, isDark),

            // 2. Scrollable Body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Failure Reason Alert (if failed/callback)
                    if (_currentOrder.isFailed) ...[
                      _buildFailureAlertBanner(isDark),
                      const SizedBox(height: 16),
                    ],

                    // 2x2 Top Summary Cards (Status, Remittance, Stock, Value)
                    _buildTopKpiRow(isDark),
                    const SizedBox(height: 20),

                    // Section: Customer & Delivery Information
                    _buildCustomerSection(isDark),
                    const SizedBox(height: 20),

                    // Section: Product, Stock & Warehouse Bin Source
                    _buildStockAndProductSection(isDark, targetStock),
                    const SizedBox(height: 20),

                    // Section: Holder & Rider Custody Information
                    _buildHolderAndRiderSection(isDark, assignedDriver, dcState.drivers),
                    const SizedBox(height: 20),

                    // Section: Financial Breakdown & Remittance Settlement
                    _buildFinancialAndRemittanceSection(isDark),
                    const SizedBox(height: 20),

                    // Proof of Delivery Evidence (if Delivered)
                    if (_currentOrder.isDelivered) ...[
                      _buildProofOfDeliverySection(isDark),
                      const SizedBox(height: 20),
                    ],
                  ],
                ),
              ),
            ),

            // 3. Footer Action Bar
            _buildFooterActions(context, isDark, assignedDriver, dcState.drivers),
          ],
        ),
      ),
    );
  }

  Widget _buildModalHeader(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.receipt_long_rounded, color: Color(0xFF2563EB), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Order ${_currentOrder.orderNumber}',
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 17),
                    ),
                    const SizedBox(width: 8),
                    _buildStatusPill(_currentOrder),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Created ${DateTimeFormatter.formatDate(_currentOrder.createdAt)} • ${_currentOrder.deliveryCity}, ${_currentOrder.deliveryState}',
                  style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded, size: 20),
            color: const Color(0xFF64748B),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusPill(OrderEntity order) {
    if (order.isDelivered) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFF10B981).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text('DELIVERED', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: const Color(0xFF059669))),
      );
    } else if (order.isFailed) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text('FAILED / CALLBACK', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: const Color(0xFFDC2626))),
      );
    } else if (order.isUnassigned) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFF64748B).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text('UNASSIGNED', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: const Color(0xFF475569))),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text('IN TRANSIT', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: const Color(0xFF7C3AED))),
      );
    }
  }

  Widget _buildFailureAlertBanner(bool isDark) {
    final reason = _currentOrder.failureReason ?? _currentOrder.deliveryNotes ?? 'Customer phone unreachable / switched off';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444).withValues(alpha: isDark ? 0.18 : 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Delivery Failed / Rescheduled Ticket',
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFFDC2626)),
                ),
                const SizedBox(height: 3),
                Text(
                  'Logged Reason: $reason',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF1E293B)),
                ),
                const SizedBox(height: 4),
                Text(
                  'Item remains securely allocated in the assigned rider\'s vehicle custody until returned to DC or redelivered.',
                  style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopKpiRow(bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 550;
        final card1 = _buildTopKpiCard(
          'Total Order Value',
          CurrencyFormatter.formatNaira(_currentOrder.totalAmount),
          _currentOrder.paymentType.replaceAll('_', ' ').toUpperCase(),
          const Color(0xFF2563EB),
          isDark,
        );

        final card2 = _buildTopKpiCard(
          'Remittance Status',
          _currentOrder.isDelivered
              ? (_currentOrder.isDirectTransfer
                  ? '⚡ Direct Transfer'
                  : (_currentOrder.isRemitted ? '🟢 Remitted & Cleared' : '🟡 In Rider Custody'))
              : (_currentOrder.isFailed ? '⚠️ Failed Attempt' : '🕒 Order in Progress'),
          _currentOrder.isRemitted && _currentOrder.remittanceReference != null
              ? 'Ref: ${_currentOrder.remittanceReference}'
              : (_currentOrder.isUnremitted ? 'Cash awaiting DC deposit' : 'Settlement pending'),
          _currentOrder.isRemitted ? const Color(0xFF10B981) : (_currentOrder.isUnremitted ? const Color(0xFFD97706) : const Color(0xFF64748B)),
          isDark,
        );

        final card3 = _buildTopKpiCard(
          'Physical Product',
          '${_currentOrder.totalPhysicalQuantity}x ${_currentOrder.productName}',
          'Merchant: ${_currentOrder.clientName}',
          const Color(0xFF8B5CF6),
          isDark,
        );

        final card4 = _buildTopKpiCard(
          'Current Custody Holder',
          _currentOrder.deliveryAgentName != null && _currentOrder.deliveryAgentName!.isNotEmpty
              ? '${_currentOrder.deliveryAgentName} (${_currentOrder.deliveryAgentCode ?? "PDA"})'
              : '🏢 DC Warehouse Pool',
          _currentOrder.deliveryAgentName != null ? 'In vehicle custody' : 'Awaiting assignment',
          _currentOrder.deliveryAgentName != null ? const Color(0xFF0284C7) : const Color(0xFF64748B),
          isDark,
        );

        if (isNarrow) {
          return Column(
            children: [
              Row(children: [Expanded(child: card1), const SizedBox(width: 8), Expanded(child: card2)]),
              const SizedBox(height: 8),
              Row(children: [Expanded(child: card3), const SizedBox(width: 8), Expanded(child: card4)]),
            ],
          );
        } else {
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
        }
      },
    );
  }

  Widget _buildTopKpiCard(String label, String value, String sub, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.12 : 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w600, color: const Color(0xFF64748B))),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(sub, style: GoogleFonts.inter(fontSize: 9.5, color: const Color(0xFF94A3B8)), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildCustomerSection(bool isDark) {
    return _buildSectionContainer(
      isDark: isDark,
      title: '👤 Customer & Destination Information',
      icon: Icons.person_pin_circle_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_currentOrder.customerName, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14)),
                    Text('Phone: ${_currentOrder.customerPhone}', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
                    if (_currentOrder.customerAltPhone != null && _currentOrder.customerAltPhone!.isNotEmpty)
                      Text('Alt Phone: ${_currentOrder.customerAltPhone}', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8))),
                  ],
                ),
              ),
              Wrap(
                spacing: 6,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _launchUri(Uri.parse('tel:${_currentOrder.customerPhone}')),
                    icon: const Icon(Icons.call, size: 14, color: Color(0xFF10B981)),
                    label: const Text('Call', style: TextStyle(fontSize: 11, color: Color(0xFF10B981), fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      side: const BorderSide(color: Color(0xFF10B981)),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _launchUri(_currentOrder.getWhatsAppLocationRequestUri(riderName: _currentOrder.deliveryAgentName)),
                    icon: const Icon(Icons.chat_bubble_outline_rounded, size: 14, color: Colors.white),
                    label: const Text('WhatsApp Pin', style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _launchUri(_currentOrder.googleMapsNavUri),
                    icon: const Icon(Icons.navigation_rounded, size: 14, color: Colors.white),
                    label: const Text('GPS Nav', style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          _buildInfoRow('📍 Delivery Address:', _currentOrder.deliveryAddress, isDark),
          const SizedBox(height: 6),
          _buildInfoRow('🏙️ City & State:', '${_currentOrder.deliveryCity}, ${_currentOrder.deliveryState}', isDark),
          if (_currentOrder.landmark != null && _currentOrder.landmark!.isNotEmpty) ...[
            const SizedBox(height: 6),
            _buildInfoRow('🏛️ Nearby Landmark:', _currentOrder.landmark!, isDark),
          ],
          const SizedBox(height: 6),
          _buildInfoRow('🎯 Geocoding Status:', _currentOrder.confidenceDisplay, isDark, valueColor: _currentOrder.isLocationVerified ? const Color(0xFF10B981) : const Color(0xFF0284C7)),
          if (_currentOrder.deliveryNotes != null && _currentOrder.deliveryNotes!.isNotEmpty) ...[
            const SizedBox(height: 6),
            _buildInfoRow('📝 Delivery Notes:', _currentOrder.deliveryNotes!, isDark),
          ],
        ],
      ),
    );
  }

  Widget _buildStockAndProductSection(bool isDark, StockItemEntity targetStock) {
    return _buildSectionContainer(
      isDark: isDark,
      title: '📦 Product & Warehouse Inventory Linkage',
      icon: Icons.inventory_2_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_currentOrder.productName, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14)),
                    Text(
                      'SKU: ${_currentOrder.productSku ?? targetStock.sku} • Merchant: ${_currentOrder.clientName}',
                      style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${_currentOrder.totalPhysicalQuantity} Units Package',
                  style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.bold, color: const Color(0xFF2563EB)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMiniStat('🏢 Storage Bin Location', _currentOrder.binLocation ?? targetStock.binLocation ?? 'BIN-A1-01', const Color(0xFF2563EB), isDark),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMiniStat('🏷️ Batch / Lot Code', _currentOrder.batchNumber ?? targetStock.batchNumber ?? 'LOT-2026-08', const Color(0xFF8B5CF6), isDark),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMiniStat('🏪 DC Shelf Available', '${targetStock.availableCount} units', const Color(0xFF10B981), isDark),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildInfoRow(
            '📦 Package Breakdown:',
            '${_currentOrder.paidQuantity} Paid Units + ${_currentOrder.freeQuantity} Free Promotional Bonus (${_currentOrder.fulfillmentType == "client_package" ? "Client Sealed Package" : "DC Shelf Stock"})',
            isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildHolderAndRiderSection(bool isDark, DCFleetDriver? assignedDriver, List<DCFleetDriver> allDrivers) {
    final hasRider = assignedDriver != null && _currentOrder.deliveryAgentId != null && _currentOrder.deliveryAgentId!.isNotEmpty;

    return _buildSectionContainer(
      isDark: isDark,
      title: '🛵 Custody Holder & Dispatch State',
      icon: Icons.two_wheeler_rounded,
      child: hasRider
          ? Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: const Color(0xFF2563EB).withValues(alpha: 0.15),
                  child: Text(assignedDriver.name.substring(0, 1), style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(assignedDriver.name, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13.5)),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(assignedDriver.driverCode, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF2563EB))),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${assignedDriver.vehicleModel} (${assignedDriver.vehiclePlate}) • Zone: ${assignedDriver.assignedZone}',
                        style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                      ),
                      Text(
                        'Phone: ${assignedDriver.phone}',
                        style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                ),
                if (!_currentOrder.isDelivered)
                  OutlinedButton.icon(
                    onPressed: () => _showReassignDialog(context, isDark, allDrivers),
                    icon: const Icon(Icons.swap_horiz_rounded, size: 14),
                    label: const Text('Reassign', style: TextStyle(fontSize: 11)),
                  ),
              ],
            )
          : Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.15 : 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: Color(0xFFD97706), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'This order is currently unassigned in the DC pool and not held in any rider\'s vehicle.',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: const Color(0xFFD97706)),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildFinancialAndRemittanceSection(bool isDark) {
    return _buildSectionContainer(
      isDark: isDark,
      title: '💰 Financial Accounting & Remittance Reconciliation',
      icon: Icons.account_balance_wallet_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                _buildFinanceRow('💰 Total Order Amount Collected:', CurrencyFormatter.formatNaira(_currentOrder.totalAmount), isDark, isBold: true),
                const SizedBox(height: 6),
                _buildFinanceRow('🛵 Less Rider Commission (Entitlement):', '- ${CurrencyFormatter.formatNaira(_currentOrder.agentEntitlement)}', isDark, valueColor: const Color(0xFF8B5CF6)),
                const SizedBox(height: 6),
                _buildFinanceRow('🚚 Less Logistics & Transport Allowance:', '- ${CurrencyFormatter.formatNaira(_currentOrder.transportFee)}', isDark, valueColor: const Color(0xFF0284C7)),
                const Divider(height: 12),
                _buildFinanceRow('🏢 Net Merchant Settlement Payable:', CurrencyFormatter.formatNaira(_currentOrder.netMerchantSettlement), isDark, isBold: true, valueColor: const Color(0xFF10B981)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Remittance Status', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B))),
                  const SizedBox(height: 2),
                  Text(
                    _currentOrder.isDirectTransfer
                        ? '⚡ Settled via Paystack / Direct Transfer'
                        : (_currentOrder.isRemitted
                            ? '🟢 Reconciled & Cleared (Ref: ${_currentOrder.remittanceReference ?? "RMT-00402"})'
                            : (_currentOrder.isDelivered ? '🟡 Cash held in Rider Custody (Unremitted)' : '🕒 Pending Fulfillment')),
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _currentOrder.isRemitted ? const Color(0xFF10B981) : (_currentOrder.isUnremitted ? const Color(0xFFD97706) : const Color(0xFF0284C7)),
                    ),
                  ),
                ],
              ),
              if (_currentOrder.isUnremitted)
                ElevatedButton.icon(
                  onPressed: () => _markOrderAsRemitted(context),
                  icon: const Icon(Icons.check_circle_outline_rounded, size: 14, color: Colors.white),
                  label: const Text('Mark Remitted / Cleared', style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProofOfDeliverySection(bool isDark) {
    return _buildSectionContainer(
      isDark: isDark,
      title: '📝 Digital Proof of Delivery (POD)',
      icon: Icons.verified_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Fulfilled & Signed by ${_currentOrder.customerName}',
                  style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold, color: const Color(0xFF10B981)),
                ),
              ),
              const SizedBox(width: 8),
              if (_currentOrder.deliveredAt != null)
                Text(
                  'Delivered: ${DateTimeFormatter.formatDate(_currentOrder.deliveredAt!)}',
                  style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionContainer({
    required bool isDark,
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: const Color(0xFF2563EB)),
              const SizedBox(width: 8),
              Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.12 : 0.06),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 9.5, color: const Color(0xFF64748B))),
          const SizedBox(height: 2),
          Text(value, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: color), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, bool isDark, {Color? valueColor}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 140,
          child: Text(label, style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B))),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: valueColor ?? (isDark ? Colors.white : const Color(0xFF0F172A)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFinanceRow(String label, String value, bool isDark, {Color? valueColor, bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 11.5, fontWeight: isBold ? FontWeight.bold : FontWeight.w500, color: const Color(0xFF64748B)),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: isBold ? 13 : 11.5,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: valueColor ?? (isDark ? Colors.white : const Color(0xFF0F172A)),
          ),
        ),
      ],
    );
  }

  Widget _buildFooterActions(BuildContext context, bool isDark, DCFleetDriver? assignedDriver, List<DCFleetDriver> allDrivers) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
        border: Border(top: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded, size: 16),
            label: const Text('Close'),
          ),
          Wrap(
            spacing: 8,
            children: [
              if (_currentOrder.isUnassigned)
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _showReassignDialog(context, isDark, allDrivers);
                  },
                  icon: const Icon(Icons.person_add_alt_1_rounded, size: 15, color: Colors.white),
                  label: const Text('Dispatch / Assign Rider', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _showReassignDialog(BuildContext context, bool isDark, List<DCFleetDriver> drivers) {
    final messenger = ScaffoldMessenger.of(context);
    final stockState = ref.read(stockProvider);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Assign Order to Rider', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
        content: SizedBox(
          width: 450,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: drivers.map((d) {
                final driverAllocations = stockState.getAllocationsForRider(d.id, d.driverCode);
                int riderUnits = 0;
                for (final a in driverAllocations) {
                  if (a.productName.toLowerCase().contains(_currentOrder.productName.toLowerCase()) ||
                      _currentOrder.productName.toLowerCase().contains(a.productName.toLowerCase())) {
                    riderUnits += a.inCustodyUnits;
                  }
                }

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFF2563EB).withValues(alpha: 0.15),
                    child: Text(d.name.substring(0, 1), style: const TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.bold)),
                  ),
                  title: Text(d.name, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13)),
                  subtitle: Text('${d.driverCode} • Zone: ${d.assignedZone} • In Vehicle: $riderUnits units', style: GoogleFonts.inter(fontSize: 11)),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    final success = await ref.read(ordersProvider.notifier).assignOrderToRider(
                          orderId: _currentOrder.id,
                          riderId: d.id,
                          riderName: d.name,
                          riderCode: d.driverCode,
                        );
                    if (mounted) {
                      setState(() {
                        _currentOrder = _currentOrder.copyWith(
                          deliveryAgentId: d.id,
                          deliveryAgentName: d.name,
                          deliveryAgentCode: d.driverCode,
                          status: 'accepted',
                          assignedAt: DateTime.now(),
                        );
                      });
                    }
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(success ? '✅ Order ${_currentOrder.orderNumber} assigned to ${d.name}!' : '⚠️ Could not assign order.'),
                        backgroundColor: success ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                      ),
                    );
                  },
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  void _markOrderAsRemitted(BuildContext context) {
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _currentOrder = _currentOrder.copyWith(
        remittanceStatus: 'cleared',
        remittanceReference: 'RMT-REC-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
        remittedAt: DateTime.now(),
      );
    });

    messenger.showSnackBar(
      SnackBar(
        content: Text('✅ Order ${_currentOrder.orderNumber} remittance marked as CLEARED & RECONCILED! (Ref: ${_currentOrder.remittanceReference})'),
        backgroundColor: const Color(0xFF10B981),
      ),
    );
  }
}
