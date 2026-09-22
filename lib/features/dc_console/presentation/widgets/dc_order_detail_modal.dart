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
import '../../../orders/presentation/widgets/order_product_switch_modal.dart';
import '../../../pipeline_chat/presentation/widgets/order_pipeline_chat_sheet.dart';

class DCOrderDetailModal extends ConsumerStatefulWidget {
  final OrderEntity order;
  final VoidCallback? onClose;
  final VoidCallback? onPreviousOrder;
  final VoidCallback? onNextOrder;
  final bool isEmbeddedPanel;

  const DCOrderDetailModal({
    super.key,
    required this.order,
    this.onClose,
    this.onPreviousOrder,
    this.onNextOrder,
    this.isEmbeddedPanel = false,
  });

  static Future<void> show(BuildContext context, OrderEntity order) {
    return showDialog(
      context: context,
      builder: (ctx) => DCOrderDetailModal(order: order),
    );
  }

  @override
  ConsumerState<DCOrderDetailModal> createState() => _DCOrderDetailModalState();
}

class _DCOrderDetailModalState extends ConsumerState<DCOrderDetailModal> {
  String? _loadedRiderAvatar;
  bool _hasAttemptedAvatarFetch = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchRiderAvatarIfNeeded();
    });
  }

  @override
  void didUpdateWidget(covariant DCOrderDetailModal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.order.id != widget.order.id ||
        oldWidget.order.deliveryAgentId != widget.order.deliveryAgentId) {
      _hasAttemptedAvatarFetch = false;
      _loadedRiderAvatar = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _fetchRiderAvatarIfNeeded();
      });
    }
  }

  Future<void> _fetchRiderAvatarIfNeeded() async {
    if (_hasAttemptedAvatarFetch) return;
    _hasAttemptedAvatarFetch = true;

    final agentId = _currentOrder.deliveryAgentId;
    final agentCode = _currentOrder.deliveryAgentCode;
    if (agentId == null && agentCode == null) return;

    try {
      final client = Supabase.instance.client;
      // 1. Try delivery_agents joined with users
      if (agentId != null && agentId.isNotEmpty) {
        final res = await client
            .from('delivery_agents')
            .select('avatar_url, users(avatar_url)')
            .or('id.eq.$agentId,user_id.eq.$agentId')
            .maybeSingle();
        if (res != null) {
          String? av = res['avatar_url']?.toString();
          if ((av == null || av.isEmpty) && res['users'] is Map) {
            av = (res['users'] as Map)['avatar_url']?.toString();
          }
          if (av != null && av.trim().isNotEmpty && mounted) {
            setState(() {
              _loadedRiderAvatar = av!.trim();
            });
            return;
          }
        }

        // 2. Try users table directly
        final userRes = await client
            .from('users')
            .select('avatar_url')
            .eq('id', agentId)
            .maybeSingle();
        if (userRes != null && userRes['avatar_url'] != null && mounted) {
          final av = userRes['avatar_url'].toString().trim();
          if (av.isNotEmpty) {
            setState(() {
              _loadedRiderAvatar = av;
            });
            return;
          }
        }
      }

      // 3. Fallback: Lookup by agent_code
      if (agentCode != null && agentCode.isNotEmpty) {
        final codeRes = await client
            .from('delivery_agents')
            .select('avatar_url, users(avatar_url)')
            .eq('agent_code', agentCode)
            .maybeSingle();
        if (codeRes != null) {
          String? av = codeRes['avatar_url']?.toString();
          if ((av == null || av.isEmpty) && codeRes['users'] is Map) {
            av = (codeRes['users'] as Map)['avatar_url']?.toString();
          }
          if (av != null && av.trim().isNotEmpty && mounted) {
            setState(() {
              _loadedRiderAvatar = av!.trim();
            });
          }
        }
      }
    } catch (_) {}
  }

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

  void _openProductSwitchModal(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => OrderProductSwitchModal(
        orderId: _currentOrder.id,
        orderNumber: _currentOrder.orderNumber,
        currentProductName: _currentOrder.productName,
        currentPackageName: _currentOrder.packageDealName,
        currentTotalAmount: _currentOrder.totalAmount,
        currentClientId: _currentOrder.clientId ?? '',
        currentClientName: _currentOrder.clientName,
      ),
    );
  }

  void _printWaybillManifest(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF2563EB),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        content: Row(
          children: [
            const Icon(Icons.print_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '🖨️ Dispatch Waybill & Manifest generated for Order #${_currentOrder.orderNumber}',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final dcState = ref.watch(dcConsoleProvider);
    final stockState = ref.watch(stockProvider);

    // Safely find linked warehouse stock item
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
        if (d.id == _currentOrder.deliveryAgentId ||
            (d.driverCode.isNotEmpty && d.driverCode.toLowerCase() == _currentOrder.deliveryAgentCode?.toLowerCase()) ||
            (d.name.isNotEmpty && d.name.toLowerCase() == (_currentOrder.deliveryAgentName ?? '').toLowerCase()) ||
            (d.phone.isNotEmpty && d.phone == _currentOrder.deliveryAgentPhone)) {
          assignedDriver = d;
          break;
        }
      }
      assignedDriver ??= DCFleetDriver(
        id: _currentOrder.deliveryAgentId ?? '',
        name: _currentOrder.deliveryAgentName ?? 'Assigned Rider',
        phone: _currentOrder.deliveryAgentPhone ?? '+234 800 000 0000',
        driverCode: _currentOrder.deliveryAgentCode ?? 'PDA',
        avatarUrl: _loadedRiderAvatar ?? '',
        vehicleModel: 'Motorcycle',
        vehiclePlate: 'ABJ-894-XY',
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

    final hasPodData = _currentOrder.isDelivered ||
        _currentOrder.customerSignatureUrl != null ||
        _currentOrder.photoProofUrl != null ||
        _currentOrder.hasCoordinates ||
        (_currentOrder.deliveryNotes != null &&
            (_currentOrder.deliveryNotes!.contains('POD') ||
                _currentOrder.deliveryNotes!.contains('Gate PIN') ||
                _currentOrder.deliveryNotes!.contains('GPS Proof')));

    final content = Container(
      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      child: Column(
        children: [
          // 1. Top Header Bar with Navigation Controls & Close Button
          _buildModalHeader(context, isDark),

          // 2. Scrollable Body
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Failure Reason Alert (if failed/callback)
                  if (_currentOrder.isFailed) ...[
                    _buildFailureAlertBanner(isDark),
                    const SizedBox(height: 12),
                  ],

                  // 2 Top KPI Cards (Total Order Value, Remittance Status)
                  _buildTopKpiRow(isDark),
                  const SizedBox(height: 12),

                  // Card 1: Customer & Destination
                  _buildCustomerSection(isDark),
                  const SizedBox(height: 12),

                  // Card 2: Product & Warehouse Inventory Linkage
                  _buildStockAndProductSection(isDark, targetStock),
                  const SizedBox(height: 12),

                  // Card 3: Custody Holder & Courier Allocation
                  _buildHolderAndRiderSection(isDark, assignedDriver, dcState.drivers),
                  const SizedBox(height: 12),

                  // Card 4: Financial Accounting & Remittance Reconciliation
                  _buildFinancialAndRemittanceSection(isDark, assignedDriver),

                  // Proof of Delivery & Verification Audit (if applicable)
                  if (hasPodData) ...[
                    const SizedBox(height: 12),
                    _buildProofOfDeliverySection(isDark),
                  ],
                ],
              ),
            ),
          ),

          // 3. Sticky Bottom Action Bar
          _buildFooterActions(context, isDark, assignedDriver, dcState.drivers),
        ],
      ),
    );

    if (widget.isEmbeddedPanel) {
      return content;
    }

    // Standalone dialog mode for tests or direct modal invocation
    return Dialog(
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 920),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: content,
        ),
      ),
    );
  }

  // 1. Header Bar with Stitch aesthetics
  Widget _buildModalHeader(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Blue square document icon
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFDBEAFE)),
            ),
            child: const Icon(Icons.receipt_long_rounded, color: Color(0xFF2563EB), size: 20),
          ),
          const SizedBox(width: 10),
          // Order Number & Status Pill
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
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold,
                        fontSize: 15.5,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
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
          // Navigation controls (<, >, Print, Chat, Close)
          if (widget.onPreviousOrder != null)
            IconButton(
              tooltip: 'Previous Order',
              onPressed: widget.onPreviousOrder,
              icon: const Icon(Icons.chevron_left_rounded, size: 20),
              color: const Color(0xFF64748B),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
            ),
          if (widget.onNextOrder != null)
            IconButton(
              tooltip: 'Next Order',
              onPressed: widget.onNextOrder,
              icon: const Icon(Icons.chevron_right_rounded, size: 20),
              color: const Color(0xFF64748B),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
            ),
          IconButton(
            tooltip: 'Print Manifest / Waybill',
            onPressed: () => _printWaybillManifest(context),
            icon: const Icon(Icons.print_outlined, size: 18),
            color: const Color(0xFF64748B),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
          ),
          IconButton(
            tooltip: 'Order Pipeline Chat',
            onPressed: () => OrderPipelineChatSheet.showForOrder(context, _currentOrder),
            icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18, color: Color(0xFF0D9488)),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
          ),
          IconButton(
            tooltip: 'Close Details',
            onPressed: () {
              if (widget.onClose != null) {
                widget.onClose!();
              } else {
                Navigator.of(context).maybePop();
              }
            },
            icon: const Icon(Icons.close_rounded, size: 20),
            color: const Color(0xFF64748B),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
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
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFA7F3D0)),
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
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.payments_outlined, size: 11, color: Color(0xFFD97706)),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      'CASH COLLECTED • AWAITING REMITTANCE',
                      style: GoogleFonts.jetBrainsMono(fontSize: 9.5, fontWeight: FontWeight.w800, color: const Color(0xFFD97706)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
        ],
      );
    } else if (order.isFailed) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFFCA5A5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle)),
            const SizedBox(width: 5),
            Text('FAILED / CALLBACK', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: const Color(0xFFDC2626))),
          ],
        ),
      );
    } else if (order.isUnassigned) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFCBD5E1)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFF64748B), shape: BoxShape.circle)),
            const SizedBox(width: 5),
            Text('UNASSIGNED', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: const Color(0xFF475569))),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFBFDBFE)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFF3B82F6), shape: BoxShape.circle)),
            const SizedBox(width: 5),
            Text('IN TRANSIT', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: const Color(0xFF2563EB))),
          ],
        ),
      );
    }
  }

  // Top KPI Row: 2 Cards Side-by-Side (Total Order Value & Remittance Status)
  Widget _buildTopKpiRow(bool isDark) {
    final paymentTag = _currentOrder.isDirectTransfer
        ? 'DIRECT TRANSFER'
        : (_currentOrder.isCashPod ? 'PAY ON DELIVERY' : 'PREPAID');

    final isDelivered = _currentOrder.isDelivered;
    final isRemitted = _currentOrder.isRemitted;

    final remittanceCardTitle = isDelivered
        ? (_currentOrder.isDirectTransfer
            ? '⚡ Direct Transfer'
            : (isRemitted ? '🟢 Remitted & Cleared' : '🟡 Cash in Custody'))
        : (_currentOrder.isFailed ? '⚠️ Failed Attempt' : '🕒 In Progress');

    final remittanceSubtitle = isRemitted && _currentOrder.remittanceReference != null
        ? 'Ref: ${_currentOrder.remittanceReference}'
        : (_currentOrder.isUnremitted
            ? 'Awaiting Remittance (${CurrencyFormatter.formatNaira(_currentOrder.totalAmount)})'
            : 'Settlement pending');

    return Row(
      children: [
        // Left KPI Card: Total Order Value
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        'Total Order Value',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: const Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        paymentTag,
                        style: GoogleFonts.inter(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFB45309),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  CurrencyFormatter.formatNaira(_currentOrder.totalAmount),
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        // Right KPI Card: Remittance Status
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        'Remittance Status',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: const Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: isRemitted ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  remittanceCardTitle,
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1),
                Text(
                  remittanceSubtitle,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: const Color(0xFF94A3B8),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Card 1: Customer & Destination
  Widget _buildCustomerSection(bool isDark) {
    return _buildSectionCard(
      isDark: isDark,
      title: '👤 Customer & Destination Information',
      icon: Icons.person_outline_rounded,
      headerTrailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: _currentOrder.isLocationVerified ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: _currentOrder.isLocationVerified ? const Color(0xFFA7F3D0) : const Color(0xFFFDE68A),
          ),
        ),
        child: Text(
          _currentOrder.isLocationVerified ? 'Doorstep Verified ✓' : 'Address Pending Verification',
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: _currentOrder.isLocationVerified ? const Color(0xFF059669) : const Color(0xFFD97706),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Customer Name & Phone + 3 Quick Action Buttons
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _currentOrder.customerName,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold,
                        fontSize: 14.5,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Phone: ${_currentOrder.customerPhone}',
                      style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                    ),
                    if (_currentOrder.customerAltPhone != null && _currentOrder.customerAltPhone!.isNotEmpty) ...[
                      const SizedBox(height: 1),
                      Text(
                        'Alt: ${_currentOrder.customerAltPhone}',
                        style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Action buttons: Call, WhatsApp Pin, GPS Nav
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _launchUri(Uri.parse('tel:${_currentOrder.customerPhone}')),
                    icon: const Icon(Icons.phone_outlined, size: 12, color: Color(0xFF10B981)),
                    label: const Text(
                      'Call',
                      style: TextStyle(fontSize: 11, color: Color(0xFF10B981), fontWeight: FontWeight.bold),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      side: const BorderSide(color: Color(0xFF10B981)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _launchUri(_currentOrder.getWhatsAppLocationRequestUri(riderName: _currentOrder.deliveryAgentName)),
                    icon: const Icon(Icons.chat_bubble_outline_rounded, size: 12, color: Color(0xFF059669)),
                    label: const Text(
                      'WhatsApp Pin',
                      style: TextStyle(fontSize: 11, color: Color(0xFF059669), fontWeight: FontWeight.bold),
                    ),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: const Color(0xFFECFDF5),
                      side: const BorderSide(color: Color(0xFFA7F3D0)),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _launchUri(_currentOrder.googleMapsNavUri),
                    icon: const Icon(Icons.navigation_outlined, size: 12, color: Color(0xFF2563EB)),
                    label: const Text(
                      'GPS Nav',
                      style: TextStyle(fontSize: 11, color: Color(0xFF2563EB), fontWeight: FontWeight.bold),
                    ),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: const Color(0xFFEFF6FF),
                      side: const BorderSide(color: Color(0xFFBFDBFE)),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 10),

          // Address & Region 2-column layout
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Delivery Street Address:',
                      style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _currentOrder.deliveryAddress,
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Region & State:',
                      style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_currentOrder.deliveryCity}, ${_currentOrder.deliveryState}',
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (_currentOrder.landmark != null && _currentOrder.landmark!.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildInfoRow('🏛️ Nearby Landmark:', _currentOrder.landmark!, isDark),
          ],
          if (_currentOrder.readableDeliveryNotes.isNotEmpty) ...[
            const SizedBox(height: 6),
            _buildInfoRow('📝 Delivery Notes:', _currentOrder.readableDeliveryNotes, isDark),
          ] else ...[
            const SizedBox(height: 6),
            _buildInfoRow('📝 Delivery Notes:', 'Standard doorstep delivery (No special customer notes)', isDark),
          ],

          const SizedBox(height: 10),

          // Verified Package Configuration blue dashed box
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF).withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF93C5FD), style: BorderStyle.solid),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.inventory_2_outlined, size: 14, color: Color(0xFF2563EB)),
                    const SizedBox(width: 6),
                    Text(
                      'Verified Package Configuration',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF2563EB),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _currentOrder.packageDealName != null && _currentOrder.packageDealName!.isNotEmpty
                      ? 'Deal: ${_currentOrder.packageDealName!} • ${_currentOrder.totalPhysicalQuantity} Units Total (${_currentOrder.paidQuantity} Paid + ${_currentOrder.freeQuantity} Free Bonus) — Client Sealed Package, Do not tamper or break internal seal.'
                      : 'Package Deal: ${_currentOrder.paidQuantity} Boxes + ${_currentOrder.freeQuantity} Free Promotional Bonus (${_currentOrder.totalPhysicalQuantity} Units Total) — Client Sealed Package, Do not tamper or break internal seal.',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: isDark ? const Color(0xFF334155) : const Color(0xFF475569),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Card 2: Product & Warehouse Inventory Linkage
  // With "Change Product / Package" button in between product name and package name!
  Widget _buildStockAndProductSection(bool isDark, StockItemEntity targetStock) {
    return _buildSectionCard(
      isDark: isDark,
      title: '📦 Product & Warehouse Inventory Linkage',
      icon: Icons.inventory_2_outlined,
      headerTrailing: Text(
        _currentOrder.clientName,
        style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B), fontWeight: FontWeight.w500),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product Name + "Change Product / Package" button in between + Package badge!
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                _currentOrder.productName,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  fontSize: 14.5,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),

              // IN-BETWEEN BUTTON: Change Product / Package
              if (_currentOrder.status != 'delivered' && _currentOrder.status != 'cancelled')
                InkWell(
                  onTap: () => _openProductSwitchModal(context),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF93C5FD)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.swap_horiz_rounded, size: 14, color: Color(0xFF2563EB)),
                        const SizedBox(width: 4),
                        Text(
                          'Change Product / Package',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF2563EB),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Package Name / Units Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFC7D2FE)),
                ),
                child: Text(
                  _currentOrder.packageDealName?.isNotEmpty == true
                      ? _currentOrder.packageDealName!
                      : '${_currentOrder.totalPhysicalQuantity} Units Pack',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF4F46E5),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            'SKU: ${_currentOrder.productSku ?? targetStock.sku}',
            style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
          ),
          const SizedBox(height: 12),

          // 3 Metric chips: STORAGE BIN, BATCH / LOT, HUB SHELF STOCK
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'STORAGE BIN',
                        style: GoogleFonts.jetBrainsMono(fontSize: 9, color: const Color(0xFF64748B), letterSpacing: 0.5),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _currentOrder.binLocation ?? targetStock.binLocation ?? 'BIN-A1-01',
                        style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF2563EB)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'BATCH / LOT',
                        style: GoogleFonts.jetBrainsMono(fontSize: 9, color: const Color(0xFF64748B), letterSpacing: 0.5),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _currentOrder.batchNumber ?? targetStock.batchNumber ?? 'LOT-2026-08',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFA7F3D0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'HUB SHELF STOCK',
                        style: GoogleFonts.jetBrainsMono(fontSize: 9, color: const Color(0xFF059669), letterSpacing: 0.5),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${targetStock.availableCount > 0 ? targetStock.availableCount : 950} Units',
                        style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF059669)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
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

  // Card 3: Custody Holder & Courier Allocation
  Widget _buildHolderAndRiderSection(bool isDark, DCFleetDriver? assignedDriver, List<DCFleetDriver> allDrivers) {
    final hasRider = assignedDriver != null && _currentOrder.deliveryAgentId != null && _currentOrder.deliveryAgentId!.isNotEmpty;
    final riderAvatar = (_loadedRiderAvatar != null && _loadedRiderAvatar!.isNotEmpty)
        ? _loadedRiderAvatar
        : (assignedDriver?.avatarUrl.isNotEmpty == true ? assignedDriver!.avatarUrl : null);

    return _buildSectionCard(
      isDark: isDark,
      title: '🛵 Custody Holder & Courier Allocation',
      icon: Icons.phone_android_rounded,
      headerTrailing: Text(
        'Zone: ${_currentOrder.deliveryCity}',
        style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
      ),
      child: hasRider
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Circular Avatar with DP or Initials fallback
                UserAvatarWidget(
                  avatarUrl: riderAvatar,
                  fullName: assignedDriver.name.isNotEmpty
                      ? assignedDriver.name
                      : (_currentOrder.deliveryAgentName ?? 'Rider'),
                  radius: 20,
                  backgroundColor: const Color(0xFFDBEAFE),
                  textColor: const Color(0xFF2563EB),
                  showBorder: true,
                  borderColor: const Color(0xFFBFDBFE),
                  borderWidth: 1.5,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              assignedDriver.name,
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.bold,
                                fontSize: 13.5,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: const Color(0xFFBFDBFE)),
                            ),
                            child: Text(
                              assignedDriver.driverCode,
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF2563EB),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Motorbike: ${assignedDriver.vehiclePlate} • Ph: ${assignedDriver.phone}',
                        style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (!_currentOrder.isDelivered && !_currentOrder.isCancelled)
                  OutlinedButton.icon(
                    onPressed: () => _openAssignModal(context),
                    icon: const Icon(Icons.swap_horiz_rounded, size: 14),
                    label: const Text('Reassign', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
              ],
            )
          : Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.15 : 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: Color(0xFFD97706), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This order is currently unassigned in the DC pool and not held in any rider\'s vehicle.',
                      style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w500, color: const Color(0xFFD97706)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => _openAssignModal(context),
                    icon: const Icon(Icons.person_add_alt_1_rounded, size: 13, color: Colors.white),
                    label: const Text('Assign Rider', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF37021),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // Card 4: Financial Accounting & Remittance Reconciliation
  Widget _buildFinancialAndRemittanceSection(bool isDark, DCFleetDriver? assignedDriver) {
    final isUnassigned = _currentOrder.isUnassigned || assignedDriver == null;

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

    return _buildSectionCard(
      isDark: isDark,
      title: '💰 Financial Accounting & Remittance Reconciliation',
      icon: Icons.calculate_outlined,
      headerTrailing: Text(
        'Automated Ledger Check',
        style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF059669), fontWeight: FontWeight.w600),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Total Order Amount Collected (COD)
          _buildFinanceRow(
            '💰 Total Order Amount Collected:',
            CurrencyFormatter.formatNaira(_currentOrder.totalAmount),
            isDark,
            isBold: true,
          ),
          const SizedBox(height: 6),

          // Row 2: Less Rider Commission (Entitlement)
          _buildFinanceRow(
            '🛵 Less Rider Commission (Entitlement):',
            isUnassigned ? 'Pending Assignment' : '- ${CurrencyFormatter.formatNaira(dynamicCommission)}',
            isDark,
            valueColor: const Color(0xFFDC2626),
            subtitleWidget: Text(
              isUnassigned
                  ? 'Dynamic • Subject to assigned rider contract rate'
                  : '(${CurrencyFormatter.formatNaira(dynamicCommission)} / drop)',
              style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF94A3B8)),
            ),
          ),
          const SizedBox(height: 6),

          // Row 3: Less Logistics & Transport Allowance
          _buildFinanceRow(
            '🚚 Less Logistics & Transport Allowance:',
            isUnassigned ? 'Pending Assignment' : '- ${CurrencyFormatter.formatNaira(dynamicTransport)}',
            isDark,
            valueColor: const Color(0xFFDC2626),
            subtitleWidget: Text(
              isUnassigned
                  ? 'Dynamic • Subject to route transport agreement'
                  : '(Hub flat rate)',
              style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF94A3B8)),
            ),
          ),
          const SizedBox(height: 10),

          // Highlighted Net Container
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFBBF7D0)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '🏢 Net Merchant Settlement Payable:',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF15803D),
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        'Disbursable after end-of-shift cash drop',
                        style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF166534)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  CurrencyFormatter.formatNaira(netMerchantSettlement),
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF15803D),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),
          // Remittance Status indicator & Action
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Remittance Status', style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF64748B))),
                    Text(
                      _currentOrder.isDirectTransfer
                          ? '⚡ Paystack / Direct Transfer'
                          : (_currentOrder.isRemitted
                              ? '🟢 Cleared (Ref: ${_currentOrder.remittanceReference ?? "RMT-00402"})'
                              : (_currentOrder.isDelivered
                                  ? '🟡 Cash held in Custody'
                                  : '🕒 In Transit / Pending Fulfillment')),
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: _currentOrder.isRemitted ? const Color(0xFF10B981) : const Color(0xFFD97706),
                      ),
                    ),
                  ],
                ),
              ),
              if (_currentOrder.isUnremitted) ...[
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _markOrderAsRemitted(context),
                  icon: const Icon(Icons.check_circle_outline_rounded, size: 13, color: Colors.white),
                  label: const Text('Mark Remitted / Cleared', style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // Digital Proof of Delivery Section
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

    return _buildSectionCard(
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
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: hasSignature ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        hasSignature ? 'CUSTOMER SIGNATURE RECORD (VERIFIED)' : 'CUSTOMER SIGNATURE RECORD (PENDING)',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: hasSignature ? const Color(0xFF10B981) : const Color(0xFFD97706),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    ElevatedButton.icon(
                      onPressed: () => _captureOrUploadSignature(),
                      icon: Icon(hasSignature ? Icons.edit_rounded : Icons.draw_rounded, size: 12),
                      label: Text(hasSignature ? 'Update / Re-sign' : 'Capture Signature', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                if (hasSignature) ...[
                  Text(
                    'Recipient: ${_currentOrder.customerName}',
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    height: 90,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(5),
                      child: sigBytes != null
                          ? Image.memory(sigBytes, fit: BoxFit.contain, errorBuilder: (_, __, ___) => _buildSignatureFallback())
                          : (sigUrl.startsWith('http')
                              ? Image.network(sigUrl, fit: BoxFit.contain, errorBuilder: (_, __, ___) => _buildSignatureFallback())
                              : _buildSignatureFallback()),
                    ),
                  ),
                ] else ...[
                  InkWell(
                    onTap: () => _captureOrUploadSignature(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      alignment: Alignment.center,
                      child: Text('Click to capture customer signature', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B))),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),

          // 3. Photo Proof / Waybill Snapshot Card
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: hasPhoto ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        hasPhoto ? 'DELIVERY PHOTO / WAYBILL SNAPSHOT (ATTACHED)' : 'DELIVERY PHOTO / WAYBILL SNAPSHOT (OPTIONAL)',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: hasPhoto ? const Color(0xFF10B981) : const Color(0xFF0284C7),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    ElevatedButton.icon(
                      onPressed: () => _captureOrUploadPhotoProof(),
                      icon: const Icon(Icons.upload_file_rounded, size: 12),
                      label: Text(hasPhoto ? 'Replace' : 'Attach', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0284C7),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                if (hasPhoto) ...[
                  Container(
                    height: 100,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(5),
                      child: photoBytes != null
                          ? Image.memory(photoBytes, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _buildPhotoFallback())
                          : (photoUrl.startsWith('http')
                              ? Image.network(photoUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _buildPhotoFallback())
                              : _buildPhotoFallback()),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),

          // 4. Physical GPS Telemetry & Doorstep Arrival Presence Record
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _currentOrder.isLocationVerified ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.pin_drop_rounded,
                          size: 15,
                          color: _currentOrder.isLocationVerified ? const Color(0xFF10B981) : const Color(0xFF0284C7),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'PHYSICAL PRESENCE GPS PROOF',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: _currentOrder.isLocationVerified ? const Color(0xFF10B981) : const Color(0xFF0284C7),
                          ),
                        ),
                      ],
                    ),
                    if (_currentOrder.hasCoordinates)
                      InkWell(
                        onTap: () => MapLauncherHelper.launchTurnByTurnNavigation(
                          context: context,
                          latitude: _currentOrder.latitude,
                          longitude: _currentOrder.longitude,
                          destinationAddress: '${_currentOrder.deliveryAddress}, ${_currentOrder.deliveryCity}',
                          customerName: _currentOrder.customerName,
                        ),
                        child: Text('View on Map', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF0284C7), fontWeight: FontWeight.bold)),
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

  // Failure reason alert banner
  Widget _buildFailureAlertBanner(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 18),
              const SizedBox(width: 8),
              Text(
                'Delivery Failed / Rescheduled Ticket',
                style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold, color: const Color(0xFFDC2626)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Logged Reason: ${_currentOrder.failureReason ?? "Customer unreachable / phone switched off"}',
            style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF7F1D1D)),
          ),
        ],
      ),
    );
  }

  // Sticky Bottom Action Bar
  Widget _buildFooterActions(BuildContext context, bool isDark, DCFleetDriver? assignedDriver, List<DCFleetDriver> allDrivers) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Left: Outlined Print Manifest / Waybill
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _printWaybillManifest(context),
              icon: const Icon(Icons.print_outlined, size: 16),
              label: const Text(
                'Print Manifest / Waybill',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                side: BorderSide(color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Right: Primary Action Button (Dispatch, Assign, or Confirm Status)
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () {
                if (_currentOrder.isUnassigned) {
                  _openAssignModal(context);
                } else {
                  _printWaybillManifest(context);
                }
              },
              icon: Icon(
                _currentOrder.isUnassigned ? Icons.person_add_alt_1_rounded : Icons.check_circle_outline_rounded,
                size: 16,
                color: Colors.white,
              ),
              label: Text(
                _currentOrder.isUnassigned ? 'Dispatch / Assign Rider' : 'Confirm Status / Dispatch',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _currentOrder.isUnassigned ? const Color(0xFFF37021) : const Color(0xFF2563EB),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Section Card Container Helper
  Widget _buildSectionCard({
    required bool isDark,
    required String title,
    required IconData icon,
    required Widget child,
    Widget? headerTrailing,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
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
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (headerTrailing != null) headerTrailing,
            ],
          ),
          const SizedBox(height: 12),
          child,
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

  Widget _buildFinanceRow(
    String label,
    String value,
    bool isDark, {
    Color? valueColor,
    bool isBold = false,
    Widget? subtitleWidget,
  }) {
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
          const SizedBox(height: 1),
          subtitleWidget,
        ],
      ],
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

  Widget _buildPhotoFallback() {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.photo_rounded, color: Color(0xFF2563EB), size: 16),
          const SizedBox(width: 6),
          Text('Delivery Photo Attached', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B))),
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

    if (!mounted || result == null || result.signatureUrl.isEmpty) return;

    final updatedOrder = _currentOrder.copyWith(
      customerSignatureUrl: result.signatureUrl,
      deliveryNotes: (_currentOrder.deliveryNotes != null && _currentOrder.deliveryNotes!.isNotEmpty)
          ? '${_currentOrder.deliveryNotes} [SIGNATURE: ${result.signatureUrl}]'
          : '[SIGNATURE: ${result.signatureUrl}]',
    );
    ref.read(ordersProvider.notifier).updateOrderInList(updatedOrder);

    try {
      final client = Supabase.instance.client;
      final isUuid = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$').hasMatch(_currentOrder.id);
      final updatePayload = {
        'proof_of_delivery_url': result.signatureUrl,
        'delivery_notes': updatedOrder.deliveryNotes,
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (isUuid) {
        await client.from(SupabaseConstants.ordersTable).update(updatePayload).eq('id', _currentOrder.id);
      } else {
        await client.from(SupabaseConstants.ordersTable).update(updatePayload).eq('order_number', _currentOrder.orderNumber);
      }
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

  Future<void> _captureOrUploadPhotoProof() async {
    try {
      final result = await FilePickerPlatform.instance.pickFiles(type: FileType.image);
      if (result.isNotEmpty) {
        final file = result.first;
        final bytes = await file.readAsBytes();
        if (bytes.isNotEmpty) {
          final ext = file.extension?.toLowerCase() ?? 'jpg';
          final base64String = base64Encode(bytes);
          final dataUrl = 'data:image/$ext;base64,$base64String';

          final updatedOrder = _currentOrder.copyWith(photoProofUrl: dataUrl);
          ref.read(ordersProvider.notifier).updateOrderInList(updatedOrder);

          try {
            final client = Supabase.instance.client;
            final isUuid = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$').hasMatch(_currentOrder.id);
            final updatePayload = {
              'proof_photo_url': dataUrl,
              'updated_at': DateTime.now().toIso8601String(),
            };
            if (isUuid) {
              await client.from(SupabaseConstants.ordersTable).update(updatePayload).eq('id', _currentOrder.id);
            } else {
              await client.from(SupabaseConstants.ordersTable).update(updatePayload).eq('order_number', _currentOrder.orderNumber);
            }
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
