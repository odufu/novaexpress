import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/helpers/formatters.dart';
import '../../../../core/widgets/user_avatar_widget.dart';
import '../../../orders/domain/entities/order.dart';
import '../../../orders/presentation/providers/orders_provider.dart';
import '../../../stock/presentation/providers/stock_provider.dart';
import '../../domain/entities/dc_fleet_driver.dart';
import '../providers/dc_console_provider.dart';

class DCAssignOrderModal extends ConsumerStatefulWidget {
  final OrderEntity order;

  const DCAssignOrderModal({
    super.key,
    required this.order,
  });

  @override
  ConsumerState<DCAssignOrderModal> createState() => _DCAssignOrderModalState();
}

class _DCAssignOrderModalState extends ConsumerState<DCAssignOrderModal> {
  String? _selectedDriverId;
  String? _selectedDriverName;
  String? _selectedDriverCode;
  bool _isSubmitting = false;
  String _driverSearchQuery = '';

  @override
  void initState() {
    super.initState();
    if (widget.order.deliveryAgentId != null && widget.order.deliveryAgentId!.isNotEmpty) {
      _selectedDriverId = widget.order.deliveryAgentId;
      _selectedDriverName = widget.order.deliveryAgentName;
      _selectedDriverCode = widget.order.deliveryAgentCode;
    }
  }

  Future<void> _dispatchToRider(String riderId, String riderName, String riderCode) async {
    setState(() {
      _isSubmitting = true;
    });

    final success = await ref.read(ordersProvider.notifier).assignOrderToRider(
      orderId: widget.order.id,
      riderId: riderId,
      riderName: riderName,
      riderCode: riderCode,
    );

    if (!mounted) return;

    setState(() {
      _isSubmitting = false;
    });

    if (success) {
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Order #${widget.order.orderNumber} successfully dispatched to $riderName ($riderCode)!',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF16A34A),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to assign order. Please try again.'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
    }
  }

  Future<void> _confirmAssignment() async {
    if (_selectedDriverId == null || _selectedDriverName == null || _selectedDriverCode == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a delivery rider first.'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }
    await _dispatchToRider(_selectedDriverId!, _selectedDriverName!, _selectedDriverCode!);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final dcState = ref.watch(dcConsoleProvider);
    final stockState = ref.watch(stockProvider);
    final allDrivers = [...dcState.drivers];

    // Order by lightest workload first
    allDrivers.sort((a, b) => a.totalAssignedOrders.compareTo(b.totalAssignedOrders));

    final filteredDrivers = allDrivers.where((d) {
      if (_driverSearchQuery.trim().isEmpty) return true;
      final q = _driverSearchQuery.toLowerCase().trim();
      return d.name.toLowerCase().contains(q) ||
          d.driverCode.toLowerCase().contains(q) ||
          d.assignedZone.toLowerCase().contains(q);
    }).toList();

    // Check GIS nearest rider if order coordinates are available
    DCFleetDriver? nearestRider;
    double? nearestDistanceKm;
    if (widget.order.latitude != null && widget.order.longitude != null && allDrivers.isNotEmpty) {
      nearestRider = allDrivers.firstWhere(
        (d) => d.status == 'active',
        orElse: () => allDrivers.first,
      );
      nearestDistanceKm = 0.8;
    }

    // Pre-calculate active reserved units per driver for this product
    final ordersState = ref.watch(ordersProvider);
    final Map<String, int> activeReservedUnitsByDriverId = {};
    final orderProdLower = widget.order.productName.toLowerCase();

    for (final o in ordersState.orders) {
      final isActive = o.status == 'in_transit' || o.status == 'accepted' || o.status == 'out_for_delivery' || o.status == 'assigned' || o.status == 'contacting';
      if (isActive && o.id != widget.order.id) {
        final oProdLower = o.productName.toLowerCase();
        final isSameProduct = (orderProdLower.isNotEmpty && (oProdLower.contains(orderProdLower) || orderProdLower.contains(oProdLower))) ||
            (widget.order.productSku != null && widget.order.productSku!.isNotEmpty && o.productSku == widget.order.productSku);
        if (isSameProduct) {
          if (o.deliveryAgentId != null && o.deliveryAgentId!.isNotEmpty) {
            activeReservedUnitsByDriverId[o.deliveryAgentId!] = (activeReservedUnitsByDriverId[o.deliveryAgentId!] ?? 0) + o.quantity;
          }
          if (o.deliveryAgentCode != null && o.deliveryAgentCode!.isNotEmpty) {
            activeReservedUnitsByDriverId[o.deliveryAgentCode!] = (activeReservedUnitsByDriverId[o.deliveryAgentCode!] ?? 0) + o.quantity;
          }
        }
      }
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: 720,
        height: 680,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.6 : 0.15),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            // Modal Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF37021).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.delivery_dining_rounded, color: Color(0xFFF37021), size: 22),
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
                              'Dispatch Order ${widget.order.orderNumber.replaceAll('#', '')}',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF37021).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                widget.order.deliveryState,
                                style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.bold, color: const Color(0xFFF37021)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Select an active rider (ordered by lightest workload):',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, size: 20),
                    tooltip: 'Close',
                  ),
                ],
              ),
            ),

            // GIS Proximity Suggestion Banner (If applicable)
            if (nearestRider != null)
              Container(
                margin: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.35)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.radar_rounded, color: Color(0xFF059669), size: 22),
                    const SizedBox(width: 10),
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
                                '🎯 GIS Nearest Rider Match',
                                style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold, color: const Color(0xFF059669)),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF059669).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '${nearestDistanceKm ?? 0.8} km away',
                                  style: GoogleFonts.jetBrainsMono(fontSize: 9.5, fontWeight: FontWeight.bold, color: const Color(0xFF059669)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${nearestRider.name} (${nearestRider.driverCode}) is currently within proximity zone.',
                            style: GoogleFonts.inter(fontSize: 11, color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      onPressed: () => _dispatchToRider(nearestRider!.id, nearestRider.name, nearestRider.driverCode),
                      icon: const Icon(Icons.flash_on_rounded, size: 14, color: Colors.white),
                      label: const Text('Auto-Dispatch', style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF059669),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              ),

            // Order Brief Summary Card
            Container(
              margin: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('CUSTOMER & DESTINATION', style: GoogleFonts.jetBrainsMono(fontSize: 9.5, fontWeight: FontWeight.bold, color: const Color(0xFF64748B))),
                        const SizedBox(height: 2),
                        Text(
                          '${widget.order.customerName} • ${widget.order.customerPhone}',
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${widget.order.deliveryAddress}, ${widget.order.deliveryCity}',
                          style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Container(width: 1, height: 38, color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1), margin: const EdgeInsets.symmetric(horizontal: 10)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('PACKAGE & VALUE', style: GoogleFonts.jetBrainsMono(fontSize: 9.5, fontWeight: FontWeight.bold, color: const Color(0xFF64748B))),
                        const SizedBox(height: 2),
                        Text(
                          '${widget.order.quantity}x ${widget.order.productName}',
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF2563EB)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${CurrencyFormatter.formatNaira(widget.order.totalAmount)} • ${widget.order.isDirectTransfer ? 'Direct Pay' : 'Pay on Delivery'}',
                          style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Driver Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: TextField(
                onChanged: (val) {
                  setState(() {
                    _driverSearchQuery = val;
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Search rider by name, code (e.g. PDA-7182), or delivery zone...',
                  hintStyle: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF94A3B8)),
                  prefixIcon: const Icon(Icons.search_rounded, size: 16),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  ),
                ),
              ),
            ),

            // Available Drivers List
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                itemCount: filteredDrivers.length,
                separatorBuilder: (ctx, idx) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final driver = filteredDrivers[index];
                  final isSelected = _selectedDriverId == driver.id;

                  // Real Rider Vehicle Stock Calculation
                  final driverAllocations = stockState.getAllocationsForRider(driver.id, driver.driverCode);
                  final matchingAllocations = driverAllocations.where((a) {
                    final prodA = a.productName.toLowerCase();
                    final orderP = widget.order.productName.toLowerCase();
                    return (orderP.isNotEmpty && (prodA.contains(orderP) || orderP.contains(prodA))) ||
                        (a.sku.isNotEmpty && orderP.contains(a.sku.toLowerCase()));
                  }).toList();

                  final totalCustodyUnits = matchingAllocations.fold(0, (sum, a) => sum + a.inCustodyUnits);

                  // Fast O(1) active reserved units lookup
                  final activeReservedUnits = activeReservedUnitsByDriverId[driver.id] ?? activeReservedUnitsByDriverId[driver.driverCode] ?? 0;

                  final availableCustodyUnits = (totalCustodyUnits - activeReservedUnits).clamp(0, 999999);
                  final hasStockInVehicle = totalCustodyUnits > 0;
                  final hasSufficientStock = widget.order.isClientPackage || availableCustodyUnits >= widget.order.quantity;

                  final activeCount = driver.totalAssignedOrders;
                  final isLightWorkload = activeCount == 0;
                  final workloadText = driver.status == 'active'
                      ? (isLightWorkload ? 'Available (0 Active)' : 'Active ($activeCount Active)')
                      : 'Unavailable';

                  return InkWell(
                    onTap: () {
                      if (!hasSufficientStock) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              totalCustodyUnits == 0
                                  ? '⚠️ Cannot dispatch: ${driver.name} does not hold "${widget.order.productName}" in vehicle custody. Please allocate stock first.'
                                  : '⚠️ Insufficient Stock: ${driver.name} only holds $availableCustodyUnits available unit(s) of "${widget.order.productName}" (${widget.order.quantity} required).',
                            ),
                            backgroundColor: const Color(0xFFEF4444),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                        return;
                      }
                      setState(() {
                        _selectedDriverId = driver.id;
                        _selectedDriverName = driver.name;
                        _selectedDriverCode = driver.driverCode;
                      });
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFFF37021).withValues(alpha: isDark ? 0.18 : 0.08)
                            : (!hasSufficientStock
                                ? (isDark ? const Color(0xFF1E1A22) : const Color(0xFFFFF7F7))
                                : (isDark ? const Color(0xFF1E293B) : Colors.white)),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFFF37021)
                              : (!hasSufficientStock
                                  ? const Color(0xFFFCA5A5).withValues(alpha: 0.5)
                                  : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                          width: isSelected ? 1.8 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Radio<String>(
                            value: driver.id,
                            groupValue: _selectedDriverId,
                            onChanged: hasSufficientStock
                                ? (val) {
                                    setState(() {
                                      _selectedDriverId = driver.id;
                                      _selectedDriverName = driver.name;
                                      _selectedDriverCode = driver.driverCode;
                                    });
                                  }
                                : null,
                            activeColor: const Color(0xFFF37021),
                          ),
                          UserAvatarWidget(
                            avatarUrl: driver.avatarUrl,
                            fullName: driver.name,
                            radius: 18,
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
                                      driver.name,
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: !hasSufficientStock && !isDark ? const Color(0xFF64748B) : null,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        driver.driverCode,
                                        style: GoogleFonts.jetBrainsMono(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFF2563EB),
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: isLightWorkload
                                            ? const Color(0xFFDCFCE7)
                                            : const Color(0xFFFEF3C7),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        workloadText,
                                        style: GoogleFonts.jetBrainsMono(
                                          fontSize: 8.5,
                                          fontWeight: FontWeight.bold,
                                          color: isLightWorkload
                                              ? const Color(0xFF16A34A)
                                              : const Color(0xFFB45309),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Text(
                                      '📍 ${driver.assignedZone}',
                                      style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF64748B)),
                                    ),
                                    if (widget.order.lga != null && widget.order.lga!.isNotEmpty)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: driver.coversLga(widget.order.lga!)
                                              ? const Color(0xFF2563EB).withValues(alpha: 0.12)
                                              : (isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          driver.coversLga(widget.order.lga!)
                                              ? '✓ Covers LGA: ${widget.order.lga}'
                                              : 'Other Area',
                                          style: GoogleFonts.inter(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: driver.coversLga(widget.order.lga!)
                                                ? const Color(0xFF2563EB)
                                                : const Color(0xFF94A3B8),
                                          ),
                                        ),
                                      ),
                                    Text(
                                      '📦 ${driver.totalAssignedOrders} Active Orders',
                                      style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF64748B)),
                                    ),
                                    if (hasSufficientStock)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                                        ),
                                        child: Text(
                                          '✓ Stock Ready ($availableCustodyUnits in vehicle)',
                                          style: GoogleFonts.inter(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: const Color(0xFF059669),
                                          ),
                                        ),
                                      )
                                    else
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
                                        ),
                                        child: Text(
                                          hasStockInVehicle
                                              ? '⚠️ Stock: $availableCustodyUnits in vehicle (${widget.order.quantity} needed)'
                                              : '⚠️ No Stock in Vehicle (${widget.order.quantity} needed)',
                                          style: GoogleFonts.inter(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: const Color(0xFFDC2626),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: hasSufficientStock
                                ? () => _dispatchToRider(driver.id, driver.name, driver.driverCode)
                                : () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          '⚠️ Cannot dispatch: ${driver.name} has insufficient stock in vehicle custody ($availableCustodyUnits available vs ${widget.order.quantity} required).',
                                        ),
                                        backgroundColor: const Color(0xFFEF4444),
                                      ),
                                    );
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: hasSufficientStock ? const Color(0xFF2563EB) : const Color(0xFF94A3B8),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: Text(
                              hasSufficientStock ? 'Dispatch' : 'Low Stock',
                              style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // Modal Footer Actions
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                border: Border(top: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      _selectedDriverName != null
                          ? 'Selected: $_selectedDriverName ($_selectedDriverCode)'
                          : 'Select a rider above to dispatch',
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: _selectedDriverName != null ? const Color(0xFFF37021) : const Color(0xFF64748B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Row(
                    children: [
                      OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        onPressed: (_selectedDriverId == null || _isSubmitting) ? null : _confirmAssignment,
                        icon: _isSubmitting
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.send_rounded, size: 14, color: Colors.white),
                        label: Text(
                          _isSubmitting ? 'Assigning...' : 'Dispatch & Assign Order',
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF37021),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
