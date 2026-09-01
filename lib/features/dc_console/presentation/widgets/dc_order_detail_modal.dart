import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/supabase_constants.dart';
import '../../../../core/helpers/formatters.dart';
import '../../../../core/helpers/map_launcher_helper.dart';
import '../../../../core/widgets/signature_pad_modal.dart';
import '../../../../core/widgets/user_avatar_widget.dart';
import '../../../orders/domain/entities/order.dart';
import '../../../orders/presentation/providers/orders_provider.dart';
import '../../../stock/domain/entities/stock_item.dart';
import '../../../stock/presentation/providers/stock_provider.dart';
import '../../domain/entities/dc_fleet_driver.dart';
import '../providers/dc_console_provider.dart';
import 'dc_assign_order_modal.dart';

class DCOrderDetailModal extends ConsumerStatefulWidget {
  final OrderEntity order;

  const DCOrderDetailModal({super.key, required this.order});

  @override
  ConsumerState<DCOrderDetailModal> createState() => _DCOrderDetailModalState();
}

class _DCOrderDetailModalState extends ConsumerState<DCOrderDetailModal> {
  OrderEntity get _currentOrder {
    final ordersState = ref.watch(ordersProvider);
    return ordersState.orders.firstWhere(
      (o) => o.id == widget.order.id || o.orderNumber == widget.order.orderNumber,
      orElse: () => widget.order,
    );
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

    // Safely find linked warehouse stock item without generic covariance casting error
    StockItemEntity? matchedStock;
    try {
      final lowerName = _currentOrder.productName.toLowerCase();
      final lowerSku = (_currentOrder.productSku ?? '').toLowerCase();
      for (final s in stockState.stockItems) {
        final sName = s.name.toLowerCase();
        final sSku = s.sku.toLowerCase();
        if (sName.contains(lowerName) || lowerName.contains(sName) || (lowerSku.isNotEmpty && sSku == lowerSku)) {
          matchedStock = s;
          break;
        }
      }
    } catch (_) {}
    final targetStock = matchedStock ??
        (stockState.stockItems.isNotEmpty ? stockState.stockItems.first : StockItemEntity.empty);

    // Safely find assigned driver entity if any
    DCFleetDriver? assignedDriver;
    if (_currentOrder.deliveryAgentId != null && _currentOrder.deliveryAgentId!.isNotEmpty) {
      for (final d in dcState.drivers) {
        if (d.id == _currentOrder.deliveryAgentId || d.driverCode == _currentOrder.deliveryAgentCode) {
          assignedDriver = d;
          break;
        }
      }
      assignedDriver ??= DCFleetDriver(
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
      );
    }

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960, maxHeight: 900),
        child: Column(
          children: [
            // 1. Header Banner
            _buildModalHeader(context, isDark),

            // 2. Scrollable Body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Failure Reason Alert (if failed/callback)
                    if (_currentOrder.isFailed) ...[
                      _buildFailureAlertBanner(isDark),
                      const SizedBox(height: 14),
                    ],

                    // 2x2 or 1x4 Top Summary Cards (Status, Remittance, Stock, Value)
                    _buildTopKpiRow(isDark),
                    const SizedBox(height: 16),

                    // Responsive Main Body: 2-Column on Desktop, 1-Column on Mobile
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isDesktop = constraints.maxWidth >= 680;
                        final hasPodData = _currentOrder.isDelivered ||
                            _currentOrder.customerSignatureUrl != null ||
                            _currentOrder.photoProofUrl != null ||
                            _currentOrder.hasCoordinates ||
                            (_currentOrder.deliveryNotes != null &&
                                (_currentOrder.deliveryNotes!.contains('POD') ||
                                    _currentOrder.deliveryNotes!.contains('Gate PIN') ||
                                    _currentOrder.deliveryNotes!.contains('GPS Proof')));

                        if (isDesktop) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Left Column: Customer & Delivery Info, Custody, Proof of Delivery
                              Expanded(
                                flex: 5,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildCustomerSection(isDark),
                                    const SizedBox(height: 16),
                                    _buildHolderAndRiderSection(isDark, assignedDriver, dcState.drivers),
                                    if (hasPodData) ...[
                                      const SizedBox(height: 16),
                                      _buildProofOfDeliverySection(isDark),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              // Right Column: Product & Warehouse Inventory, Financial Accounting
                              Expanded(
                                flex: 5,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildStockAndProductSection(isDark, targetStock),
                                    const SizedBox(height: 16),
                                    _buildFinancialAndRemittanceSection(isDark, assignedDriver),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }

                        // Mobile Single-Column Flow
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildCustomerSection(isDark),
                            const SizedBox(height: 16),
                            _buildStockAndProductSection(isDark, targetStock),
                            const SizedBox(height: 16),
                            _buildHolderAndRiderSection(isDark, assignedDriver, dcState.drivers),
                            const SizedBox(height: 16),
                            _buildFinancialAndRemittanceSection(isDark, assignedDriver),
                            if (hasPodData) ...[
                              const SizedBox(height: 16),
                              _buildProofOfDeliverySection(isDark),
                            ],
                          ],
                        );
                      },
                    ),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.receipt_long_rounded, color: Color(0xFF2563EB), size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'Order ${_currentOrder.orderNumber}',
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15.5),
                    ),
                    _buildStatusPill(_currentOrder),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Created ${DateTimeFormatter.formatDate(_currentOrder.createdAt)} • ${_currentOrder.deliveryCity}, ${_currentOrder.deliveryState}',
                  style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF64748B)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded, size: 20),
            color: const Color(0xFF64748B),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusPill(OrderEntity order) {
    if (order.isDelivered) {
      final isCashAwaitingRemittance = order.isUnremitted && !order.isDirectTransfer;
      return Wrap(
        spacing: 6,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle_rounded, size: 11, color: Color(0xFF059669)),
                const SizedBox(width: 4),
                Text('DELIVERED ✓', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: const Color(0xFF059669))),
              ],
            ),
          ),
          if (isCashAwaitingRemittance)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.payments_outlined, size: 11, color: Color(0xFFD97706)),
                  const SizedBox(width: 4),
                  Text('CASH COLLECTED • AWAITING REMITTANCE', style: GoogleFonts.jetBrainsMono(fontSize: 9.5, fontWeight: FontWeight.w800, color: const Color(0xFFD97706))),
                ],
              ),
            ),
        ],
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
        final isNarrow = constraints.maxWidth < 600;
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
                  : (_currentOrder.isRemitted ? '🟢 Remitted & Cleared' : '🟡 Cash in Custody'))
              : (_currentOrder.isFailed ? '⚠️ Failed Attempt' : '🕒 In Progress'),
          _currentOrder.isRemitted && _currentOrder.remittanceReference != null
              ? 'Ref: ${_currentOrder.remittanceReference}'
              : (_currentOrder.isUnremitted
                  ? 'Awaiting Remittance (${CurrencyFormatter.formatNaira(_currentOrder.totalAmount)})'
                  : 'Settlement pending'),
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
          'Custody Holder',
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.12 : 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 3),
          Text(
            value,
            style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold, color: color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 1),
          Text(sub, style: GoogleFonts.inter(fontSize: 9, color: const Color(0xFF94A3B8)), maxLines: 1, overflow: TextOverflow.ellipsis),
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
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 420;
              final custInfo = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_currentOrder.customerName, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text('Phone: ${_currentOrder.customerPhone}', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
                  if (_currentOrder.customerAltPhone != null && _currentOrder.customerAltPhone!.isNotEmpty) ...[
                    const SizedBox(height: 1),
                    Text('Alt Phone: ${_currentOrder.customerAltPhone}', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8))),
                  ],
                ],
              );

              final actionBtns = Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _launchUri(Uri.parse('tel:${_currentOrder.customerPhone}')),
                    icon: const Icon(Icons.call, size: 13, color: Color(0xFF10B981)),
                    label: const Text('Call', style: TextStyle(fontSize: 11, color: Color(0xFF10B981), fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      side: const BorderSide(color: Color(0xFF10B981)),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _launchUri(_currentOrder.getWhatsAppLocationRequestUri(riderName: _currentOrder.deliveryAgentName)),
                    icon: const Icon(Icons.chat_bubble_outline_rounded, size: 13, color: Colors.white),
                    label: const Text('WhatsApp Pin', style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _launchUri(_currentOrder.googleMapsNavUri),
                    icon: const Icon(Icons.navigation_rounded, size: 13, color: Colors.white),
                    label: const Text('GPS Nav', style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              );

              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    custInfo,
                    const SizedBox(height: 10),
                    actionBtns,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: custInfo),
                  const SizedBox(width: 8),
                  actionBtns,
                ],
              );
            },
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
          if (_currentOrder.hasCoordinates || _currentOrder.loggedGpsProof != null) ...[
            const SizedBox(height: 6),
            _buildInfoRow(
              '📍 GPS Presence Proof:',
              '${_currentOrder.hasCoordinates ? "${_currentOrder.latitude!.toStringAsFixed(5)}°, ${_currentOrder.longitude!.toStringAsFixed(5)}°" : _currentOrder.loggedGpsProof} (${_currentOrder.isLocationVerified ? "Verified Doorstep ✓" : "Captured"})',
              isDark,
              valueColor: const Color(0xFF10B981),
            ),
          ],
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
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 440;
              final titleCol = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_currentOrder.productName, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14)),
                  Text(
                    'SKU: ${_currentOrder.productSku ?? targetStock.sku} • Merchant: ${_currentOrder.clientName}',
                    style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                  ),
                ],
              );

              final pkgBadge = Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${_currentOrder.totalPhysicalQuantity} Units Package',
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF2563EB)),
                ),
              );

              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    titleCol,
                    const SizedBox(height: 6),
                    pkgBadge,
                  ],
                );
              }

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: titleCol),
                  const SizedBox(width: 8),
                  pkgBadge,
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 460;
              final stat1 = _buildMiniStat('🏢 Storage Bin', _currentOrder.binLocation ?? targetStock.binLocation ?? 'BIN-A1-01', const Color(0xFF2563EB), isDark);
              final stat2 = _buildMiniStat('🏷️ Batch / Lot', _currentOrder.batchNumber ?? targetStock.batchNumber ?? 'LOT-2026-08', const Color(0xFF8B5CF6), isDark);
              final stat3 = _buildMiniStat('🏪 Shelf Stock', '${targetStock.availableCount} units', const Color(0xFF10B981), isDark);

              if (isNarrow) {
                return Column(
                  children: [
                    Row(children: [Expanded(child: stat1), const SizedBox(width: 8), Expanded(child: stat2)]),
                    const SizedBox(height: 8),
                    stat3,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: stat1),
                  const SizedBox(width: 8),
                  Expanded(child: stat2),
                  const SizedBox(width: 8),
                  Expanded(child: stat3),
                ],
              );
            },
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
          ? LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 460;
                final riderInfo = Row(
                  children: [
                    UserAvatarWidget(
                      avatarUrl: assignedDriver.avatarUrl,
                      fullName: assignedDriver.name,
                      radius: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                assignedDriver.name,
                                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13.5),
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
                                  assignedDriver.isPda ? 'PDA Rider' : 'In-House Rider',
                                  style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.bold, color: const Color(0xFF10B981)),
                                ),
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
                  ],
                );

                final reassignBtn = OutlinedButton.icon(
                  onPressed: () => _openAssignModal(context),
                  icon: const Icon(Icons.swap_horiz_rounded, size: 14),
                  label: const Text('Reassign Rider', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                );

                if (isNarrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      riderInfo,
                      if (!_currentOrder.isDelivered && !_currentOrder.isCancelled) ...[
                        const SizedBox(height: 10),
                        SizedBox(width: double.infinity, child: reassignBtn),
                      ],
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: riderInfo),
                    if (!_currentOrder.isDelivered && !_currentOrder.isCancelled) ...[
                      const SizedBox(width: 8),
                      reassignBtn,
                    ],
                  ],
                );
              },
            )
          : Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.15 : 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 440;
                  final unassignedText = Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline_rounded, color: Color(0xFFD97706), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'This order is currently unassigned in the DC pool and not held in any rider\'s vehicle.',
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: const Color(0xFFD97706)),
                        ),
                      ),
                    ],
                  );

                  final assignBtn = ElevatedButton.icon(
                    onPressed: () => _openAssignModal(context),
                    icon: const Icon(Icons.person_add_alt_1_rounded, size: 14, color: Colors.white),
                    label: const Text('Assign Rider', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF37021),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  );

                  if (isNarrow) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        unassignedText,
                        const SizedBox(height: 10),
                        SizedBox(width: double.infinity, child: assignBtn),
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(child: unassignedText),
                      const SizedBox(width: 10),
                      assignBtn,
                    ],
                  );
                },
              ),
            ),
    );
  }

  Widget _buildFinancialAndRemittanceSection(bool isDark, DCFleetDriver? assignedDriver) {
    final isUnassigned = _currentOrder.isUnassigned || assignedDriver == null;

    // Dynamic Rider Terms: Unassigned = Pending; Assigned = Real contract rates
    final double dynamicCommission = isUnassigned
        ? 0.0
        : (_currentOrder.agentEntitlement > 0
            ? _currentOrder.agentEntitlement
            : (assignedDriver.commissionRate > 0 ? assignedDriver.commissionRate : 1000.0));

    final double dynamicTransport = isUnassigned
        ? 0.0
        : (_currentOrder.transportFee > 0
            ? _currentOrder.transportFee
            : (assignedDriver.transportAllowance > 0 ? assignedDriver.transportAllowance : 1500.0));

    final double netMerchantSettlement = isUnassigned
        ? _currentOrder.totalAmount
        : (_currentOrder.totalAmount - dynamicCommission - dynamicTransport > 0
            ? _currentOrder.totalAmount - dynamicCommission - dynamicTransport
            : 0.0);

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
                _buildFinanceRow(
                  '💰 Total Order Amount Collected:',
                  CurrencyFormatter.formatNaira(_currentOrder.totalAmount),
                  isDark,
                  isBold: true,
                ),
                const SizedBox(height: 8),
                _buildFinanceRow(
                  '🛵 Less Rider Commission (Entitlement):',
                  isUnassigned
                      ? 'Pending Rider Assignment'
                      : '- ${CurrencyFormatter.formatNaira(dynamicCommission)}',
                  isDark,
                  valueColor: isUnassigned ? const Color(0xFF64748B) : const Color(0xFF8B5CF6),
                  subtitleWidget: Text(
                    isUnassigned
                        ? 'Dynamic • Determined by assigned rider contract terms upon dispatch'
                        : '${assignedDriver.isPda ? "PDA Dynamic Rate" : "In-House Fixed Rate"} @ ${CurrencyFormatter.formatNaira(dynamicCommission)} / drop',
                    style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF94A3B8)),
                  ),
                ),
                const SizedBox(height: 8),
                _buildFinanceRow(
                  '🚚 Less Logistics & Transport Allowance:',
                  isUnassigned
                      ? 'Pending Rider Assignment'
                      : '- ${CurrencyFormatter.formatNaira(dynamicTransport)}',
                  isDark,
                  valueColor: isUnassigned ? const Color(0xFF64748B) : const Color(0xFF0284C7),
                  subtitleWidget: Text(
                    isUnassigned
                        ? 'Dynamic • Subject to assigned rider transport agreement'
                        : '${CurrencyFormatter.formatNaira(dynamicTransport)} route & vehicle transport allowance',
                    style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF94A3B8)),
                  ),
                ),
                const Divider(height: 16),
                _buildFinanceRow(
                  '🏢 Net Merchant Settlement Payable:',
                  isUnassigned
                      ? '${CurrencyFormatter.formatNaira(netMerchantSettlement)} (Pre-Dispatch)'
                      : CurrencyFormatter.formatNaira(netMerchantSettlement),
                  isDark,
                  isBold: true,
                  valueColor: const Color(0xFF10B981),
                  subtitleWidget: Text(
                    isUnassigned
                        ? 'Gross order amount (Rider commission & transport deducted upon dispatch)'
                        : 'Net settlement payable to merchant after deducting rider commission & transport',
                    style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF10B981).withValues(alpha: 0.85)),
                  ),
                ),
              ],
            ),
          ),
          if (isUnassigned) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF0284C7).withValues(alpha: isDark ? 0.15 : 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded, size: 15, color: Color(0xFF0284C7)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Dynamic Remittance Accounting: Rider commission and transport allowances are not fixed. They depend entirely on the specific rider assigned and will be finalized upon dispatch.',
                      style: GoogleFonts.inter(fontSize: 10.5, color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF0369A1), height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final statusCol = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Remittance Status', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B))),
                  const SizedBox(height: 2),
                  Text(
                    _currentOrder.isDirectTransfer
                        ? '⚡ Settled via Paystack / Direct Transfer'
                        : (_currentOrder.isRemitted
                            ? '🟢 Reconciled & Cleared (Ref: ${_currentOrder.remittanceReference ?? "RMT-00402"})'
                            : (_currentOrder.isDelivered
                                ? '🟡 Cash held in Rider Custody (Unremitted)'
                                : (_currentOrder.isUnassigned ? '🕒 Pre-Dispatch (Pending Rider)' : '🕒 In Transit / Pending Fulfillment'))),
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _currentOrder.isRemitted
                          ? const Color(0xFF10B981)
                          : (_currentOrder.isUnremitted
                              ? const Color(0xFFD97706)
                              : const Color(0xFF0284C7)),
                    ),
                  ),
                ],
              );

              if (!_currentOrder.isUnremitted) {
                return statusCol;
              }

              final markBtn = ElevatedButton.icon(
                onPressed: () => _markOrderAsRemitted(context),
                icon: const Icon(Icons.check_circle_outline_rounded, size: 14, color: Colors.white),
                label: const Text('Mark Remitted / Cleared', style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
              );

              if (constraints.maxWidth < 440) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    statusCol,
                    const SizedBox(height: 8),
                    SizedBox(width: double.infinity, child: markBtn),
                  ],
                );
              }

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: statusCol),
                  const SizedBox(width: 8),
                  markBtn,
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _captureOrUploadSignature() async {
    final result = await SignaturePadModal.show(
      context: context,
      orderId: _currentOrder.id,
      customerName: _currentOrder.customerName,
    );

    if (!mounted) return;

    if (result != null && result.signatureUrl.isNotEmpty) {
      final updatedOrder = _currentOrder.copyWith(
        customerSignatureUrl: result.signatureUrl,
        deliveryNotes: (_currentOrder.deliveryNotes != null && _currentOrder.deliveryNotes!.isNotEmpty)
            ? '${_currentOrder.deliveryNotes} [SIGNATURE: ${result.signatureUrl}]'
            : '[SIGNATURE: ${result.signatureUrl}]',
      );
      ref.read(ordersProvider.notifier).updateOrderInList(updatedOrder);

      try {
        final client = Supabase.instance.client;
        await client.from(SupabaseConstants.ordersTable).update({
          'proof_of_delivery_url': result.signatureUrl,
          'delivery_notes': updatedOrder.deliveryNotes,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', _currentOrder.id);
      } catch (e) {
        debugPrint('[DC_ORDER_DETAIL] ℹ️ Supabase signature update notice: $e');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF16A34A),
            content: Text('✓ Proof of Delivery signature attached successfully!'),
          ),
        );
      }
    }
  }

  Future<void> _captureOrUploadPhotoProof() async {
    try {
      final result = await FilePickerPlatform.instance.pickFiles(
        type: FileType.image,
      );

      if (result.isNotEmpty) {
        final file = result.first;
        final bytes = await file.readAsBytes();
        if (bytes.isNotEmpty) {
          final ext = file.extension?.toLowerCase() ?? 'jpg';
          final base64String = base64Encode(bytes);
          final dataUrl = 'data:image/$ext;base64,$base64String';

          final updatedOrder = _currentOrder.copyWith(
            photoProofUrl: dataUrl,
          );
          ref.read(ordersProvider.notifier).updateOrderInList(updatedOrder);

          try {
            final client = Supabase.instance.client;
            await client.from(SupabaseConstants.ordersTable).update({
              'proof_photo_url': dataUrl,
              'updated_at': DateTime.now().toIso8601String(),
            }).eq('id', _currentOrder.id);
          } catch (e) {
            debugPrint('[DC_ORDER_DETAIL] ℹ️ Supabase photo update notice: $e');
          }

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                backgroundColor: Color(0xFF16A34A),
                content: Text('✓ Delivery photo proof attached successfully!'),
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('[DC_ORDER_DETAIL] ⚠️ Photo upload error: $e');
    }
  }

  Widget _buildProofOfDeliverySection(bool isDark) {
    String? sigUrl = _currentOrder.customerSignatureUrl;
    if ((sigUrl == null || sigUrl.isEmpty) && _currentOrder.deliveryNotes != null) {
      final match = RegExp(r'\[(?:Audit\s+)?SIGNATURE:\s*([^\]]+)\]', caseSensitive: false)
          .firstMatch(_currentOrder.deliveryNotes!);
      if (match != null) sigUrl = match.group(1)?.trim();
    }

    String? photoUrl = _currentOrder.photoProofUrl;
    if ((photoUrl == null || photoUrl.isEmpty) && _currentOrder.deliveryNotes != null) {
      final match = RegExp(r'\[(?:Audit\s+)?(?:PHOTO|IMAGE|WAYBILL):\s*([^\]]+)\]', caseSensitive: false)
          .firstMatch(_currentOrder.deliveryNotes!);
      if (match != null) photoUrl = match.group(1)?.trim();
    }

    final hasSignature = sigUrl != null && sigUrl.isNotEmpty;
    final hasPhoto = photoUrl != null && photoUrl.isNotEmpty;

    Uint8List? sigBytes;
    if (hasSignature && sigUrl.startsWith('data:image')) {
      try {
        final commaIdx = sigUrl.indexOf(',');
        if (commaIdx != -1) {
          sigBytes = base64Decode(sigUrl.substring(commaIdx + 1));
        }
      } catch (_) {}
    }

    Uint8List? photoBytes;
    if (hasPhoto && photoUrl.startsWith('data:image')) {
      try {
        final commaIdx = photoUrl.indexOf(',');
        if (commaIdx != -1) {
          photoBytes = base64Decode(photoUrl.substring(commaIdx + 1));
        }
      } catch (_) {}
    }

    final isCashAwaitingRemittance = _currentOrder.isDelivered && _currentOrder.isUnremitted && !_currentOrder.isDirectTransfer;

    return _buildSectionContainer(
      isDark: isDark,
      title: '📝 Digital Proof of Delivery (POD) & Verification Audit',
      icon: Icons.verified_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Prominent Cash Collection & Custody Status Banner
          if (isCashAwaitingRemittance) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.18 : 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF59E0B),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.payments_rounded, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '💵 Cash Collected • Awaiting DC Remittance',
                          style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold, color: const Color(0xFFD97706)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Amount of ${CurrencyFormatter.formatNaira(_currentOrder.totalAmount)} is held in rider vehicle custody (${_currentOrder.deliveryAgentName ?? "Assigned Rider"} - ${_currentOrder.deliveryAgentCode ?? "PDA"}).',
                          style: GoogleFonts.inter(fontSize: 11, color: isDark ? Colors.white70 : const Color(0xFF475569)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          // 2. Customer Signature Record Card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: hasSignature
                    ? const Color(0xFF10B981).withValues(alpha: 0.4)
                    : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                width: hasSignature ? 1.5 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 460;
                    final headerLeft = Row(
                      children: [
                        Icon(
                          hasSignature ? Icons.check_circle_rounded : Icons.pending_actions_rounded,
                          size: 16,
                          color: hasSignature ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            hasSignature ? 'CUSTOMER SIGNATURE RECORD (VERIFIED)' : 'CUSTOMER SIGNATURE RECORD (PENDING)',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: hasSignature ? const Color(0xFF10B981) : const Color(0xFFD97706),
                              letterSpacing: 0.5,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    );

                    final headerActions = Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (hasSignature)
                          IconButton(
                            icon: const Icon(Icons.fullscreen_rounded, size: 18),
                            tooltip: 'View Full Signature',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () => _showFullSignaturePreview(context, sigUrl!, isDark),
                          ),
                        const SizedBox(width: 6),
                        ElevatedButton.icon(
                          onPressed: () => _captureOrUploadSignature(),
                          icon: Icon(hasSignature ? Icons.edit_rounded : Icons.draw_rounded, size: 13),
                          label: Text(hasSignature ? 'Update / Re-sign' : 'Capture Signature', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: hasSignature ? const Color(0xFF0284C7) : const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ],
                    );

                    if (isNarrow) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          headerLeft,
                          const SizedBox(height: 6),
                          headerActions,
                        ],
                      );
                    }

                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: headerLeft),
                        headerActions,
                      ],
                    );
                  },
                ),
                const SizedBox(height: 8),
                if (hasSignature) ...[
                  Text(
                    'Recipient: ${_currentOrder.customerName}',
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () => _showFullSignaturePreview(context, sigUrl!, isDark),
                    child: Container(
                      height: 120,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(7),
                        child: sigBytes != null
                            ? Image.memory(
                                sigBytes,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => _buildSignatureFallback(),
                              )
                            : (sigUrl.startsWith('http://') || sigUrl.startsWith('https://')
                                ? Image.network(
                                    sigUrl,
                                    fit: BoxFit.contain,
                                    loadingBuilder: (ctx, child, progress) => progress == null
                                        ? child
                                        : const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                    errorBuilder: (_, __, ___) => _buildSignatureFallback(),
                                  )
                                : _buildSignatureFallback()),
                      ),
                    ),
                  ),
                ] else ...[
                  InkWell(
                    onTap: () => _captureOrUploadSignature(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
                      alignment: Alignment.center,
                      child: Column(
                        children: [
                          Icon(Icons.draw_rounded, size: 26, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                          const SizedBox(height: 4),
                          Text(
                            'No digital signature on file for this order',
                            style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : const Color(0xFF334155)),
                          ),
                          Text(
                            'Click to capture recipient signature on pad',
                            style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 3. Delivery Photo Proof / Waybill Snapshot Card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: hasPhoto
                    ? const Color(0xFF10B981).withValues(alpha: 0.4)
                    : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                width: hasPhoto ? 1.5 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 460;
                    final headerLeft = Row(
                      children: [
                        Icon(
                          hasPhoto ? Icons.photo_camera_rounded : Icons.add_photo_alternate_outlined,
                          size: 16,
                          color: hasPhoto ? const Color(0xFF10B981) : const Color(0xFF0284C7),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            hasPhoto ? 'DELIVERY PHOTO / WAYBILL SNAPSHOT (ATTACHED)' : 'DELIVERY PHOTO / WAYBILL SNAPSHOT (OPTIONAL)',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: hasPhoto ? const Color(0xFF10B981) : const Color(0xFF0284C7),
                              letterSpacing: 0.5,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    );

                    final headerActions = Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (hasPhoto)
                          IconButton(
                            icon: const Icon(Icons.fullscreen_rounded, size: 18),
                            tooltip: 'View Full Photo',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () => _showFullPhotoPreview(context, photoUrl!, isDark),
                          ),
                        const SizedBox(width: 6),
                        ElevatedButton.icon(
                          onPressed: () => _captureOrUploadPhotoProof(),
                          icon: Icon(hasPhoto ? Icons.photo_camera_rounded : Icons.upload_file_rounded, size: 13),
                          label: Text(hasPhoto ? 'Replace Photo' : 'Attach Photo', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: hasPhoto ? const Color(0xFF0284C7) : const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ],
                    );

                    if (isNarrow) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          headerLeft,
                          const SizedBox(height: 6),
                          headerActions,
                        ],
                      );
                    }

                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: headerLeft),
                        headerActions,
                      ],
                    );
                  },
                ),
                const SizedBox(height: 8),
                if (hasPhoto) ...[
                  GestureDetector(
                    onTap: () => _showFullPhotoPreview(context, photoUrl!, isDark),
                    child: Container(
                      height: 140,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(7),
                        child: photoBytes != null
                            ? Image.memory(
                                photoBytes,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => _buildPhotoFallback(),
                              )
                            : (photoUrl.startsWith('http://') || photoUrl.startsWith('https://')
                                ? Image.network(
                                    photoUrl,
                                    fit: BoxFit.cover,
                                    loadingBuilder: (ctx, child, progress) => progress == null
                                        ? child
                                        : const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                    errorBuilder: (_, __, ___) => _buildPhotoFallback(),
                                  )
                                : _buildPhotoFallback()),
                      ),
                    ),
                  ),
                ] else ...[
                  InkWell(
                    onTap: () => _captureOrUploadPhotoProof(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
                      alignment: Alignment.center,
                      child: Column(
                        children: [
                          Icon(Icons.add_a_photo_outlined, size: 26, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                          const SizedBox(height: 4),
                          Text(
                            'No parcel or waybill photo attached yet',
                            style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : const Color(0xFF334155)),
                          ),
                          Text(
                            'Click to upload doorstep delivery snapshot or physical waybill',
                            style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 4. Physical GPS Telemetry & Doorstep Arrival Presence Record
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _currentOrder.isLocationVerified
                    ? const Color(0xFF10B981).withValues(alpha: 0.4)
                    : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
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
                          Icon(
                            Icons.pin_drop_rounded,
                            size: 16,
                            color: _currentOrder.isLocationVerified
                                ? const Color(0xFF10B981)
                                : const Color(0xFF0284C7),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'PHYSICAL PRESENCE GPS PROOF',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: _currentOrder.isLocationVerified
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFF0284C7),
                                letterSpacing: 0.5,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (_currentOrder.hasCoordinates)
                      InkWell(
                        onTap: () {
                          MapLauncherHelper.launchTurnByTurnNavigation(
                            context: context,
                            latitude: _currentOrder.latitude,
                            longitude: _currentOrder.longitude,
                            destinationAddress: '${_currentOrder.deliveryAddress}, ${_currentOrder.deliveryCity}',
                            customerName: _currentOrder.customerName,
                          );
                        },
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.map_outlined, size: 12, color: Color(0xFF0284C7)),
                              const SizedBox(width: 4),
                              Text(
                                'View on Map',
                                style: GoogleFonts.inter(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF0284C7),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                _buildInfoRow(
                  '📍 Arrival Coordinates:',
                  _currentOrder.hasCoordinates
                      ? '${_currentOrder.latitude!.toStringAsFixed(5)}°, ${_currentOrder.longitude!.toStringAsFixed(5)}°'
                      : (_currentOrder.loggedGpsProof ?? 'Logged on Fulfillment'),
                  isDark,
                ),
                const SizedBox(height: 4),
                _buildInfoRow(
                  '🚪 Gate Pass PIN:',
                  _currentOrder.effectiveGatePin,
                  isDark,
                  valueColor: const Color(0xFFEA580C),
                ),
                const SizedBox(height: 4),
                _buildInfoRow(
                  '🛡️ Verification State:',
                  _currentOrder.isLocationVerified
                      ? '✓ Real-time GPS Presence Verified & Committed to Database'
                      : 'Pending Physical Verification',
                  isDark,
                  valueColor: _currentOrder.isLocationVerified ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoFallback() {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.photo_library_rounded, color: Color(0xFF10B981), size: 16),
          const SizedBox(width: 6),
          Text('Delivery Photo Attached', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B))),
        ],
      ),
    );
  }

  Widget _buildSignatureFallback() {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.verified_rounded, color: Color(0xFF10B981), size: 16),
          const SizedBox(width: 6),
          Text('Digital Signature Attached', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B))),
        ],
      ),
    );
  }

  void _showFullPhotoPreview(BuildContext context, String photoUrl, bool isDark) {
    Uint8List? bytes;
    if (photoUrl.startsWith('data:image')) {
      try {
        final commaIdx = photoUrl.indexOf(',');
        if (commaIdx != -1) bytes = base64Decode(photoUrl.substring(commaIdx + 1));
      } catch (_) {}
    }

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700, maxHeight: 600),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Proof of Delivery (POD) Photo / Waybill', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text('Order #${_currentOrder.orderNumber} • ${_currentOrder.customerName}', style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B))),
                      ],
                    ),
                    IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close_rounded)),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(11),
                      child: bytes != null
                          ? Image.memory(bytes, fit: BoxFit.contain)
                          : (photoUrl.startsWith('http://') || photoUrl.startsWith('https://')
                              ? Image.network(photoUrl, fit: BoxFit.contain)
                              : _buildPhotoFallback()),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showFullSignaturePreview(BuildContext context, String sigUrl, bool isDark) {
    Uint8List? bytes;
    if (sigUrl.startsWith('data:image')) {
      try {
        final commaIdx = sigUrl.indexOf(',');
        if (commaIdx != -1) bytes = base64Decode(sigUrl.substring(commaIdx + 1));
      } catch (_) {}
    }

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 500),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Proof of Delivery (POD) Signature', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text('Order #${_currentOrder.orderNumber} • ${_currentOrder.customerName}', style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B))),
                      ],
                    ),
                    IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close_rounded)),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(11),
                      child: bytes != null
                          ? Image.memory(bytes, fit: BoxFit.contain)
                          : (sigUrl.startsWith('http://') || sigUrl.startsWith('https://')
                              ? Image.network(sigUrl, fit: BoxFit.contain)
                              : _buildSignatureFallback()),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
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
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 360;
        if (isNarrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B))),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: valueColor ?? (isDark ? Colors.white : const Color(0xFF0F172A)),
                ),
              ),
            ],
          );
        }
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
      },
    );
  }

  Widget _buildFinanceRow(String label, String value, bool isDark, {Color? valueColor, bool isBold = false, Widget? subtitleWidget}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 11.5,
                  fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
                  color: const Color(0xFF64748B),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: isBold ? 13 : 11.5,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                color: valueColor ?? (isDark ? Colors.white : const Color(0xFF0F172A)),
              ),
            ),
          ],
        ),
        if (subtitleWidget != null) ...[
          const SizedBox(height: 2),
          subtitleWidget,
        ],
      ],
    );
  }

  Widget _buildFooterActions(BuildContext context, bool isDark, DCFleetDriver? assignedDriver, List<DCFleetDriver> allDrivers) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
        border: Border(top: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 400;

          final closeBtn = TextButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded, size: 16),
            label: const Text('Close'),
          );

          final actionBtn = _currentOrder.isUnassigned
              ? ElevatedButton.icon(
                  onPressed: () => _openAssignModal(context),
                  icon: const Icon(Icons.person_add_alt_1_rounded, size: 15, color: Colors.white),
                  label: const Text('Dispatch / Assign Rider', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF37021),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                )
              : (!_currentOrder.isDelivered && !_currentOrder.isCancelled
                  ? OutlinedButton.icon(
                      onPressed: () => _openAssignModal(context),
                      icon: const Icon(Icons.swap_horiz_rounded, size: 15),
                      label: const Text('Reassign Rider', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    )
                  : null);

          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (actionBtn != null) ...[
                  actionBtn,
                  const SizedBox(height: 6),
                ],
                closeBtn,
              ],
            );
          }

          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              closeBtn,
              if (actionBtn != null) actionBtn,
            ],
          );
        },
      ),
    );
  }

  Future<void> _openAssignModal(BuildContext context) async {
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => DCAssignOrderModal(order: _currentOrder),
    );
  }

  void _markOrderAsRemitted(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final order = _currentOrder;
    final refCode = 'RMT-REC-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

    await ref.read(ordersProvider.notifier).updateOrderRemittance(
      orderId: order.id,
      remittanceStatus: 'cleared',
      remittanceReference: refCode,
    );

    messenger.showSnackBar(
      SnackBar(
        content: Text('✅ Order ${order.orderNumber} remittance marked as CLEARED & RECONCILED! (Ref: $refCode)'),
        backgroundColor: const Color(0xFF10B981),
      ),
    );
  }
}
