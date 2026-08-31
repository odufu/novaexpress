import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/helpers/formatters.dart';
import '../../../../core/widgets/user_avatar_widget.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../finance/domain/entities/remittance.dart';
import '../../../finance/presentation/providers/finance_provider.dart';
import '../../../orders/domain/entities/order.dart';
import '../../../orders/presentation/providers/orders_provider.dart';
import '../../domain/entities/dc_fleet_driver.dart';
import '../providers/dc_console_provider.dart';
import '../widgets/dc_contact_rider_modal.dart';
import '../widgets/dc_remittance_detail_modal.dart';
import '../widgets/dc_rider_detail_modal.dart';

final dcOrderMatchingSearchProvider = StateProvider.autoDispose<String>((ref) => '');
final dcOrderMatchingFilterProvider = StateProvider.autoDispose<String>((ref) => 'all');
final dcOrderMatchingRiderFilterProvider = StateProvider.autoDispose<String?>((ref) => null);
final dcOrderMatchingTableViewProvider = StateProvider.autoDispose<bool>((ref) => true);
final dcOrderMatchingDateFilterProvider = StateProvider.autoDispose<String>((ref) => 'all_time');
final dcOrderMatchingPageProvider = StateProvider.autoDispose<int>((ref) => 1);
final dcOrderMatchingRowsPerPageProvider = StateProvider.autoDispose<int>((ref) => 15);

class DCOrderPaymentMatchingPage extends ConsumerStatefulWidget {
  const DCOrderPaymentMatchingPage({super.key});

  @override
  DCOrderPaymentMatchingPageState createState() => DCOrderPaymentMatchingPageState();
}

class DCOrderPaymentMatchingPageState extends ConsumerState<DCOrderPaymentMatchingPage> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounceTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(authProvider).user;
      final activeDcId = user?.distributionCenterId ?? '22222222-2222-4222-8222-222222222222';
      ref.read(ordersProvider.notifier).loadDcOrders(activeDcId);
      ref.read(financeProvider.notifier).loadRemittances(activeDcId);
      ref.read(dcConsoleProvider.notifier).loadDriversFromDatabase();
    });
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String val) {
    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = Timer(const Duration(milliseconds: 180), () {
      if (mounted) {
        ref.read(dcOrderMatchingPageProvider.notifier).state = 1;
        ref.read(dcOrderMatchingSearchProvider.notifier).state = val;
      }
    });
  }

  /// High-Performance O(1) Driver Resolver using Hash Maps
  DCFleetDriver? _resolveDriverFast(
    String? agentId,
    String? agentCode,
    String? agentName,
    Map<String, DCFleetDriver> driverById,
    Map<String, DCFleetDriver> driverByCode,
    Map<String, DCFleetDriver> driverByName,
    List<DCFleetDriver> allDrivers,
  ) {
    if (allDrivers.isEmpty) return null;

    // 1. Exact ID
    if (agentId != null && agentId.isNotEmpty && driverById.containsKey(agentId)) {
      return driverById[agentId];
    }

    // 2. Exact Driver Code (case-insensitive)
    if (agentCode != null && agentCode.isNotEmpty && agentCode != 'PDA-7000') {
      final match = driverByCode[agentCode.toLowerCase()];
      if (match != null) return match;
    }

    // 3. Exact Name (case-insensitive)
    if (agentName != null && agentName.isNotEmpty && agentName != 'Fleet Rider') {
      final match = driverByName[agentName.toLowerCase()];
      if (match != null) return match;
    }

    // 4. Fallback code
    if (agentCode != null && agentCode.isNotEmpty) {
      final match = driverByCode[agentCode.toLowerCase()];
      if (match != null) return match;
    }

    // 5. If only 1 driver exists
    if (allDrivers.length == 1) {
      return allDrivers.first;
    }

    return null;
  }

  @visibleForTesting
  List<DCRemittanceLifecycleItem> buildRemittanceLifecycleItemsForTest(
    List<OrderEntity> allOrders,
    List<RemittanceEntity> allRemittances,
    DCConsoleState dcState,
  ) =>
      _buildRemittanceLifecycleItems(allOrders, allRemittances, dcState);

  /// High-Performance Unified Remittance Lifecycle Generator with Pre-Indexed Hash Lookups
  List<DCRemittanceLifecycleItem> _buildRemittanceLifecycleItems(
    List<OrderEntity> allOrders,
    List<RemittanceEntity> allRemittances,
    DCConsoleState dcState,
  ) {
    final List<DCRemittanceLifecycleItem> items = [];

    // Pre-Index Drivers into O(1) Lookup Maps
    final Map<String, DCFleetDriver> driverById = {};
    final Map<String, DCFleetDriver> driverByCode = {};
    final Map<String, DCFleetDriver> driverByName = {};

    for (final d in dcState.drivers) {
      if (d.id.isNotEmpty) driverById[d.id] = d;
      if (d.driverCode.isNotEmpty) driverByCode[d.driverCode.toLowerCase()] = d;
      if (d.name.isNotEmpty) driverByName[d.name.toLowerCase()] = d;
    }

    // Pre-Index Orders into O(1) Lookup Maps
    final Map<String, OrderEntity> ordersById = {};
    final Map<String, OrderEntity> ordersByNumber = {};
    final Set<String> verifiedOrderNumbers = {};

    for (final rem in allRemittances) {
      if (rem.isVerified) {
        for (final ao in rem.associatedOrders) {
          if (ao.orderId.isNotEmpty) verifiedOrderNumbers.add(ao.orderId);
          if (ao.orderNumber.isNotEmpty) verifiedOrderNumbers.add(ao.orderNumber);
        }
      }
    }

    for (final o in allOrders) {
      ordersById[o.id] = o;
      ordersByNumber[o.orderNumber] = o;
    }

    // 1. Group UNREMITTED Cash on Delivery Orders by Rider to form Open Batches
    final Map<String, List<OrderEntity>> unremittedCashByRider = {};
    for (final order in allOrders) {
      if (order.isDirectTransfer) continue;
      if (order.status == 'delivered') {
        final isRemitted = order.remittanceStatus.toLowerCase() == 'remitted' ||
            order.remittanceStatus.toLowerCase() == 'cleared' ||
            verifiedOrderNumbers.contains(order.id) ||
            verifiedOrderNumbers.contains(order.orderNumber);

        if (!isRemitted) {
          final riderKey = order.deliveryAgentId ?? order.deliveryAgentCode ?? 'unassigned';
          unremittedCashByRider.putIfAbsent(riderKey, () => []).add(order);
        }
      }
    }

    // Create an open batch item for each rider with unremitted cash orders
    unremittedCashByRider.forEach((riderKey, riderOrders) {
      riderOrders.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      final firstOrder = riderOrders.first;
      final totalGross = riderOrders.fold(0.0, (sum, o) => sum + o.totalAmount);
      final riderCommission = riderOrders.length * dcState.financeSettings.defaultCommissionRate;
      final transportAllowance = dcState.financeSettings.defaultTransportAllowance;
      final posFee = dcState.financeSettings.computePosFee(totalGross);
      final netDue = (totalGross - riderCommission - transportAllowance - posFee).clamp(0.0, totalGross);

      final resolvedDriver = _resolveDriverFast(
        firstOrder.deliveryAgentId ?? riderKey,
        firstOrder.deliveryAgentCode,
        firstOrder.deliveryAgentName,
        driverById,
        driverByCode,
        driverByName,
        dcState.drivers,
      );

      final riderName = (resolvedDriver?.name.isNotEmpty == true && resolvedDriver!.name != 'Fleet Rider')
          ? resolvedDriver.name
          : (firstOrder.deliveryAgentName != null && firstOrder.deliveryAgentName!.isNotEmpty && firstOrder.deliveryAgentName != 'Fleet Rider'
              ? firstOrder.deliveryAgentName!
              : (resolvedDriver?.name ?? (dcState.drivers.isNotEmpty ? dcState.drivers.first.name : 'Emeka Rider')));

      final riderCode = (resolvedDriver?.driverCode.isNotEmpty == true && resolvedDriver!.driverCode != 'PDA-7000')
          ? resolvedDriver.driverCode
          : (firstOrder.deliveryAgentCode ?? (resolvedDriver?.driverCode ?? (dcState.drivers.isNotEmpty ? dcState.drivers.first.driverCode : 'PDA-7000')));

      final riderAvatarUrl = resolvedDriver?.avatarUrl ?? '';
      final riderPhone = resolvedDriver?.phone ?? firstOrder.deliveryAgentPhone ?? firstOrder.customerPhone;

      items.add(
        DCRemittanceLifecycleItem(
          id: 'batch-$riderKey',
          referenceNumber: 'REM-CASH-$riderCode',
          riderId: resolvedDriver?.id ?? firstOrder.deliveryAgentId ?? riderKey,
          riderName: riderName,
          riderCode: riderCode,
          riderAvatarUrl: riderAvatarUrl,
          riderPhone: riderPhone,
          type: 'cash_pod',
          status: 'awaiting_remittance',
          openingDate: firstOrder.createdAt,
          closingDate: null,
          grossAmount: totalGross,
          commissionAmount: riderCommission,
          transportAllowance: transportAllowance,
          posFee: posFee,
          netAmount: netDue,
          orders: riderOrders,
          paymentMethod: 'cash_to_dc',
        ),
      );
    });

    // 2. Add Direct Transfer (Paystack / Monnify) Instant Settled Remittances
    for (final order in allOrders) {
      if (order.isDirectTransfer || (order.status == 'delivered' && (order.paymentType == 'direct_transfer' || order.paymentType == 'prepaid'))) {
        final resolvedDriver = _resolveDriverFast(
          order.deliveryAgentId,
          order.deliveryAgentCode,
          order.deliveryAgentName,
          driverById,
          driverByCode,
          driverByName,
          dcState.drivers,
        );

        final riderName = (resolvedDriver?.name.isNotEmpty == true && resolvedDriver!.name != 'Fleet Rider')
            ? resolvedDriver.name
            : (order.deliveryAgentName != null && order.deliveryAgentName!.isNotEmpty && order.deliveryAgentName != 'Fleet Rider'
                ? order.deliveryAgentName!
                : (resolvedDriver?.name ?? (dcState.drivers.isNotEmpty ? dcState.drivers.first.name : 'Emeka Rider')));

        final riderCode = (resolvedDriver?.driverCode.isNotEmpty == true && resolvedDriver!.driverCode != 'PDA-7000')
            ? resolvedDriver.driverCode
            : (order.deliveryAgentCode ?? (resolvedDriver?.driverCode ?? (dcState.drivers.isNotEmpty ? dcState.drivers.first.driverCode : 'PDA-7000')));

        final riderAvatarUrl = resolvedDriver?.avatarUrl ?? '';
        final riderPhone = resolvedDriver?.phone ?? order.deliveryAgentPhone ?? '08031234567';

        items.add(
          DCRemittanceLifecycleItem(
            id: 'dt-${order.id}',
            referenceNumber: 'DT-${order.orderNumber}',
            riderId: resolvedDriver?.id ?? order.deliveryAgentId ?? 'rider-unknown',
            riderName: riderName,
            riderCode: riderCode,
            riderAvatarUrl: riderAvatarUrl,
            riderPhone: riderPhone,
            type: 'direct_transfer',
            status: 'direct_settled',
            openingDate: order.createdAt,
            closingDate: order.createdAt,
            grossAmount: order.totalAmount,
            commissionAmount: 0.0,
            transportAllowance: 0.0,
            posFee: 0.0,
            netAmount: order.totalAmount,
            orders: [order],
            paymentMethod: 'direct_transfer',
          ),
        );
      }
    }

    // 3. Add Remitted & Cleared Cash Batches from financeState.remittances (O(1) Order Linking)
    final Set<String> processedOrderIds = <String>{};
    for (final rem in allRemittances) {
      if (rem.paymentMethod != 'direct_transfer') {
        final List<OrderEntity> matchingOrders = [];

        for (final ao in rem.associatedOrders) {
          if (ao.orderId.isNotEmpty && ordersById.containsKey(ao.orderId)) {
            matchingOrders.add(ordersById[ao.orderId]!);
          } else if (ao.orderNumber.isNotEmpty && ordersByNumber.containsKey(ao.orderNumber)) {
            matchingOrders.add(ordersByNumber[ao.orderNumber]!);
          }
        }

        // Also check if any order's delivery_notes references this remittance reference
        for (final o in allOrders) {
          if (!matchingOrders.any((mo) => mo.id == o.id)) {
            if (o.deliveryNotes?.contains(rem.referenceNumber) == true ||
                rem.referenceNumber.contains(o.orderNumber) ||
                rem.notes?.contains(o.orderNumber) == true) {
              matchingOrders.add(o);
            }
          }
        }

        for (final mo in matchingOrders) {
          processedOrderIds.add(mo.id);
        }

        final firstMatch = matchingOrders.isNotEmpty ? matchingOrders.first : null;
        final resolvedDriver = _resolveDriverFast(
          rem.deliveryAgentId,
          firstMatch?.deliveryAgentCode,
          firstMatch?.deliveryAgentName,
          driverById,
          driverByCode,
          driverByName,
          dcState.drivers,
        );

        final riderName = (resolvedDriver?.name.isNotEmpty == true && resolvedDriver!.name != 'Fleet Rider')
            ? resolvedDriver.name
            : (firstMatch?.deliveryAgentName != null && firstMatch!.deliveryAgentName!.isNotEmpty && firstMatch.deliveryAgentName != 'Fleet Rider'
                ? firstMatch.deliveryAgentName!
                : (resolvedDriver?.name ?? (dcState.drivers.isNotEmpty ? dcState.drivers.first.name : 'Emeka Rider')));

        final riderCode = (resolvedDriver?.driverCode.isNotEmpty == true && resolvedDriver!.driverCode != 'PDA-7000')
            ? resolvedDriver.driverCode
            : (firstMatch?.deliveryAgentCode ?? (resolvedDriver?.driverCode ?? (dcState.drivers.isNotEmpty ? dcState.drivers.first.driverCode : 'PDA-7000')));

        final riderAvatarUrl = resolvedDriver?.avatarUrl ?? '';
        final riderPhone = resolvedDriver?.phone ?? firstMatch?.deliveryAgentPhone ?? '08031234567';

        final gross = rem.grossCollections > 0 ? rem.grossCollections : rem.amount;
        final commission = rem.commissionDeducted;
        final transport = rem.transportAllowanceDeducted;
        final pos = rem.posFee;
        final net = rem.amount;

        items.add(
          DCRemittanceLifecycleItem(
            id: rem.id,
            referenceNumber: rem.referenceNumber,
            riderId: resolvedDriver?.id ?? rem.deliveryAgentId,
            riderName: riderName,
            riderCode: riderCode,
            riderAvatarUrl: riderAvatarUrl,
            riderPhone: riderPhone,
            type: 'cash_pod',
            status: rem.isVerified ? 'verified' : (rem.isPending ? 'pending_audit' : rem.status),
            openingDate: rem.createdAt,
            closingDate: rem.verifiedAt ?? rem.createdAt,
            grossAmount: gross,
            commissionAmount: commission,
            transportAllowance: transport,
            posFee: pos,
            netAmount: net,
            orders: matchingOrders,
            paymentMethod: rem.paymentMethod.isNotEmpty ? rem.paymentMethod : 'paystack',
          ),
        );
      }
    }

    // Also include individually remitted orders not yet grouped
    for (final order in allOrders) {
      if (!order.isDirectTransfer &&
          order.status == 'delivered' &&
          (order.remittanceStatus.toLowerCase() == 'remitted' || order.remittanceStatus.toLowerCase() == 'cleared') &&
          !processedOrderIds.contains(order.id)) {
        final resolvedDriver = _resolveDriverFast(
          order.deliveryAgentId,
          order.deliveryAgentCode,
          order.deliveryAgentName,
          driverById,
          driverByCode,
          driverByName,
          dcState.drivers,
        );

        final riderName = (resolvedDriver?.name.isNotEmpty == true && resolvedDriver!.name != 'Fleet Rider')
            ? resolvedDriver.name
            : (order.deliveryAgentName != null && order.deliveryAgentName!.isNotEmpty && order.deliveryAgentName != 'Fleet Rider'
                ? order.deliveryAgentName!
                : (resolvedDriver?.name ?? (dcState.drivers.isNotEmpty ? dcState.drivers.first.name : 'Emeka Rider')));

        final riderCode = (resolvedDriver?.driverCode.isNotEmpty == true && resolvedDriver!.driverCode != 'PDA-7000')
            ? resolvedDriver.driverCode
            : (order.deliveryAgentCode ?? (resolvedDriver?.driverCode ?? (dcState.drivers.isNotEmpty ? dcState.drivers.first.driverCode : 'PDA-7000')));

        final riderAvatarUrl = resolvedDriver?.avatarUrl ?? '';
        final riderPhone = resolvedDriver?.phone ?? order.deliveryAgentPhone ?? '08031234567';

        items.add(
          DCRemittanceLifecycleItem(
            id: 'rem-${order.id}',
            referenceNumber: 'REM-${order.orderNumber}',
            riderId: resolvedDriver?.id ?? order.deliveryAgentId ?? 'rider-unknown',
            riderName: riderName,
            riderCode: riderCode,
            riderAvatarUrl: riderAvatarUrl,
            riderPhone: riderPhone,
            type: 'cash_pod',
            status: 'verified',
            openingDate: order.createdAt,
            closingDate: order.remittedAt ?? order.createdAt.add(const Duration(hours: 3)),
            grossAmount: order.totalAmount,
            commissionAmount: dcState.financeSettings.defaultCommissionRate,
            transportAllowance: dcState.financeSettings.defaultTransportAllowance,
            posFee: dcState.financeSettings.computePosFee(order.totalAmount),
            netAmount: (order.totalAmount - dcState.financeSettings.defaultCommissionRate - dcState.financeSettings.defaultTransportAllowance - dcState.financeSettings.computePosFee(order.totalAmount)).clamp(0.0, order.totalAmount),
            orders: [order],
            paymentMethod: 'cash_to_dc',
          ),
        );
      }
    }

    // Sort: Not Remitted open batches first (oldest openingDate first to prompt long term accumulators), then Cleared batches
    items.sort((a, b) {
      if (!a.isVerified && b.isVerified) return -1;
      if (a.isVerified && !b.isVerified) return 1;
      if (!a.isVerified && !b.isVerified) {
        return a.openingDate.compareTo(b.openingDate);
      }
      return (b.closingDate ?? b.openingDate).compareTo(a.closingDate ?? a.openingDate);
    });

    return items;
  }

  List<DCRemittanceLifecycleItem> _filterRemittances(
    List<DCRemittanceLifecycleItem> items,
    String selectedFilter,
    String? selectedRiderFilter,
    String searchQuery,
    String dateFilter,
  ) {
    final query = searchQuery.trim().toLowerCase();
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);

    return items.where((item) {
      // 1. Status Filter (Remitted vs Not Remitted)
      if (selectedFilter == 'not_remitted' && (item.isVerified || item.isDirectTransfer)) return false;
      if (selectedFilter == 'remitted' && (!item.isVerified || item.isDirectTransfer)) return false;
      if (selectedFilter == 'direct_paystack' && !item.isDirectTransfer) return false;

      // 2. Rider Filter
      if (selectedRiderFilter != null && selectedRiderFilter.isNotEmpty) {
        if (item.riderCode != selectedRiderFilter && item.riderId != selectedRiderFilter) return false;
      }

      // 3. Opening Date Filter
      final date = item.openingDate;
      if (dateFilter == 'today') {
        if (date.isBefore(todayStart) || date.isAfter(todayEnd)) return false;
      } else if (dateFilter == 'yesterday') {
        final yesterdayStart = todayStart.subtract(const Duration(days: 1));
        final yesterdayEnd = todayStart.subtract(const Duration(seconds: 1));
        if (date.isBefore(yesterdayStart) || date.isAfter(yesterdayEnd)) return false;
      } else if (dateFilter == 'this_week') {
        final weekStart = todayStart.subtract(Duration(days: now.weekday - 1));
        if (date.isBefore(weekStart)) return false;
      } else if (dateFilter == 'this_month') {
        final monthStart = DateTime(now.year, now.month, 1);
        if (date.isBefore(monthStart)) return false;
      } else if (dateFilter == 'older') {
        final cutoff = todayStart.subtract(const Duration(days: 1));
        if (date.isAfter(cutoff)) return false;
      }

      // 4. Search Query
      if (query.isNotEmpty) {
        final matchRider = item.riderName.toLowerCase().contains(query);
        final matchCode = item.riderCode.toLowerCase().contains(query);
        final matchRef = item.referenceNumber.toLowerCase().contains(query);
        final matchOrders = item.orders.any((o) =>
            o.orderNumber.toLowerCase().contains(query) ||
            o.customerName.toLowerCase().contains(query) ||
            o.deliveryCity.toLowerCase().contains(query) ||
            o.productName.toLowerCase().contains(query));

        if (!matchRider && !matchCode && !matchRef && !matchOrders) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  String _formatDateShort(DateTime dt) {
    return DateFormat('dd MMM, hh:mm a').format(dt);
  }

  void _openRiderProfile(DCRemittanceLifecycleItem item) {
    final dcState = ref.read(dcConsoleProvider);
    final matchedDriver = dcState.drivers.where((d) =>
        (item.riderId.isNotEmpty && d.id == item.riderId) ||
        (item.riderCode.isNotEmpty && d.driverCode.toLowerCase() == item.riderCode.toLowerCase()) ||
        (item.riderName.isNotEmpty && d.name.toLowerCase() == item.riderName.toLowerCase())
    ).firstOrNull;

    final driver = matchedDriver ?? DCFleetDriver(
      id: item.riderId,
      driverCode: item.riderCode,
      name: item.riderName,
      phone: item.riderPhone ?? '08031234567',
      avatarUrl: item.riderAvatarUrl ?? '',
      vehicleModel: 'Bajaj Boxer 150',
      vehiclePlate: 'ABJ-894-XA',
      vehicleType: 'Motorcycle',
      status: 'active',
      assignedZone: 'Abuja Municipal',
      totalAssignedOrders: item.orderCount,
      completedOrders: item.orderCount,
      routeProgressPercent: 100.0,
      efficiencyRating: 98.5,
      cashInCustody: item.grossAmount,
      itemsInCustody: item.orderCount,
    );

    DCRiderDetailModal.show(context, driver);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final ordersState = ref.watch(ordersProvider);
    final financeState = ref.watch(financeProvider);
    final dcState = ref.watch(dcConsoleProvider);
    final selectedFilter = ref.watch(dcOrderMatchingFilterProvider);
    final selectedRiderFilter = ref.watch(dcOrderMatchingRiderFilterProvider);
    final searchQuery = ref.watch(dcOrderMatchingSearchProvider);
    final isTableView = ref.watch(dcOrderMatchingTableViewProvider);
    final dateFilter = ref.watch(dcOrderMatchingDateFilterProvider);
    final currentPage = ref.watch(dcOrderMatchingPageProvider);
    final rowsPerPage = ref.watch(dcOrderMatchingRowsPerPageProvider);
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;

    final allOrders = ordersState.orders;
    final allRemittances = financeState.remittances;

    // Fast Single-Pass Processing
    final allLifecycleItems = _buildRemittanceLifecycleItems(allOrders, allRemittances, dcState);
    final filteredItems = _filterRemittances(allLifecycleItems, selectedFilter, selectedRiderFilter, searchQuery, dateFilter);

    // Compute Key Metrics
    final totalMonitoredValue = allOrders.fold(0.0, (sum, o) => sum + o.totalAmount);
    final directPaystackItems = allLifecycleItems.where((i) => i.isDirectTransfer).toList();
    final directPaystackSum = directPaystackItems.fold(0.0, (sum, i) => sum + i.grossAmount);

    final notRemittedItems = allLifecycleItems.where((i) => !i.isVerified && !i.isDirectTransfer).toList();
    final notRemittedGross = notRemittedItems.fold(0.0, (sum, i) => sum + i.grossAmount);
    final notRemittedNet = notRemittedItems.fold(0.0, (sum, i) => sum + i.netAmount);

    final remittedItems = allLifecycleItems.where((i) => i.isVerified && !i.isDirectTransfer).toList();
    final remittedSum = remittedItems.fold(0.0, (sum, i) => sum + i.grossAmount);

    // Compute Pagination Slice
    final totalPages = (filteredItems.length / rowsPerPage).ceil().clamp(1, 9999);
    final safePage = currentPage.clamp(1, totalPages);
    final startIndex = (safePage - 1) * rowsPerPage;
    final endIndex = (startIndex + rowsPerPage).clamp(0, filteredItems.length);
    final pagedItems = filteredItems.sublist(startIndex, endIndex);

    // Get unique list of assigned riders for dropdown filter
    final uniqueRiders = <String, String>{};
    for (final i in allLifecycleItems) {
      if (i.riderCode.isNotEmpty) {
        uniqueRiders[i.riderCode] = i.riderName;
      }
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B1120) : const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 14 : 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Page Header Bar (RepaintBoundary)
            RepaintBoundary(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF37021).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.payments_rounded, color: Color(0xFFF37021), size: 22),
                            ),
                            const SizedBox(width: 10),
                            Flexible(
                              child: Text(
                                'Remittances & Reconciliation',
                                style: GoogleFonts.inter(
                                  fontSize: isMobile ? 17 : 21,
                                  fontWeight: FontWeight.w900,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Rider cash holding lifecycles, cumulative settlement breakdowns, and instant direct transfer clearances.',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, color: Color(0xFF64748B)),
                    tooltip: 'Refresh Remittances',
                    onPressed: () {
                      final user = ref.read(authProvider).user;
                      final activeDcId = user?.distributionCenterId ?? '22222222-2222-4222-8222-222222222222';
                      ref.read(ordersProvider.notifier).loadDcOrders(activeDcId);
                      ref.read(financeProvider.notifier).loadRemittances(activeDcId);
                      ref.read(dcConsoleProvider.notifier).loadDriversFromDatabase();
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // 2. 4 KPI Contextual Summary Cards (RepaintBoundary)
            RepaintBoundary(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final double cardWidth;
                  if (constraints.maxWidth < 600) {
                    cardWidth = constraints.maxWidth;
                  } else if (constraints.maxWidth < 1100) {
                    cardWidth = (constraints.maxWidth - 12) / 2;
                  } else {
                    cardWidth = (constraints.maxWidth - 36) / 4;
                  }

                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _buildSummaryCard(
                        title: 'TOTAL MONITORED VALUE',
                        value: CurrencyFormatter.formatNaira(totalMonitoredValue),
                        subtext: '${allOrders.length} Shipments Audited',
                        icon: Icons.receipt_long_rounded,
                        iconColor: const Color(0xFF3B82F6),
                        bgColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                        width: cardWidth,
                        isDark: isDark,
                      ),
                      _buildSummaryCard(
                        title: 'DIRECT PAYSTACK PAID',
                        value: CurrencyFormatter.formatNaira(directPaystackSum),
                        subtext: '${directPaystackItems.length} Direct Settlements • ₦0 Held',
                        icon: Icons.bolt_rounded,
                        iconColor: const Color(0xFF00A2D3),
                        bgColor: isDark ? const Color(0xFF0C243B) : const Color(0xFFF0F9FF),
                        borderColor: isDark ? const Color(0xFF0369A1) : const Color(0xFFBAE6FD),
                        width: cardWidth,
                        isDark: isDark,
                      ),
                      _buildSummaryCard(
                        title: 'NOT REMITTED (HELD BY RIDERS)',
                        value: CurrencyFormatter.formatNaira(notRemittedNet),
                        subtext: '${notRemittedItems.length} Open Batches (${CurrencyFormatter.formatNaira(notRemittedGross)} Gross)',
                        icon: Icons.warning_amber_rounded,
                        iconColor: const Color(0xFFF59E0B),
                        bgColor: isDark ? const Color(0xFF2D2305) : const Color(0xFFFFFBEB),
                        borderColor: isDark ? const Color(0xFFB45309) : const Color(0xFFFDE68A),
                        width: cardWidth,
                        isDark: isDark,
                      ),
                      _buildSummaryCard(
                        title: 'REMITTED & RECONCILED',
                        value: CurrencyFormatter.formatNaira(remittedSum),
                        subtext: '${remittedItems.length} Batches Cleared into Treasury',
                        icon: Icons.check_circle_rounded,
                        iconColor: const Color(0xFF10B981),
                        bgColor: isDark ? const Color(0xFF062D1F) : const Color(0xFFECFDF5),
                        borderColor: isDark ? const Color(0xFF047857) : const Color(0xFFA7F3D0),
                        width: cardWidth,
                        isDark: isDark,
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 18),

            // 3. Multi-Attribute Filter Toolbar Card (RepaintBoundary)
            RepaintBoundary(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: LayoutBuilder(
                  builder: (context, boxConstraints) {
                    final isNarrow = boxConstraints.maxWidth < 750;

                    final searchBox = Container(
                      height: 42,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: _onSearchChanged,
                        style: GoogleFonts.inter(fontSize: 13, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                        decoration: InputDecoration(
                          hintText: 'Search by Rider Name, Code, Ref #, or Order...',
                          hintStyle: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
                          prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF64748B)),
                          suffixIcon: searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded, size: 16),
                                  onPressed: () {
                                    _searchController.clear();
                                    ref.read(dcOrderMatchingPageProvider.notifier).state = 1;
                                    ref.read(dcOrderMatchingSearchProvider.notifier).state = '';
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 11),
                        ),
                      ),
                    );

                    final dateDropdown = Container(
                      height: 42,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: dateFilter,
                          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF64748B)),
                          dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                          items: [
                            DropdownMenuItem(value: 'all_time', child: Text('📅 All Time', style: GoogleFonts.inter(fontSize: 12, color: isDark ? Colors.white : const Color(0xFF0F172A)), overflow: TextOverflow.ellipsis)),
                            DropdownMenuItem(value: 'today', child: Text('📅 Today', style: GoogleFonts.inter(fontSize: 12, color: isDark ? Colors.white : const Color(0xFF0F172A)), overflow: TextOverflow.ellipsis)),
                            DropdownMenuItem(value: 'yesterday', child: Text('📅 Yesterday', style: GoogleFonts.inter(fontSize: 12, color: isDark ? Colors.white : const Color(0xFF0F172A)), overflow: TextOverflow.ellipsis)),
                            DropdownMenuItem(value: 'this_week', child: Text('📅 This Week', style: GoogleFonts.inter(fontSize: 12, color: isDark ? Colors.white : const Color(0xFF0F172A)), overflow: TextOverflow.ellipsis)),
                            DropdownMenuItem(value: 'this_month', child: Text('📅 This Month', style: GoogleFonts.inter(fontSize: 12, color: isDark ? Colors.white : const Color(0xFF0F172A)), overflow: TextOverflow.ellipsis)),
                            DropdownMenuItem(value: 'older', child: Text('⚠️ Long-Term (> 2 Days)', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFFF59E0B)), overflow: TextOverflow.ellipsis)),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              ref.read(dcOrderMatchingPageProvider.notifier).state = 1;
                              ref.read(dcOrderMatchingDateFilterProvider.notifier).state = val;
                            }
                          },
                        ),
                      ),
                    );

                    final riderDropdown = Container(
                      height: 42,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String?>(
                          isExpanded: true,
                          value: selectedRiderFilter,
                          hint: Text('All Fleet Riders', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)), overflow: TextOverflow.ellipsis),
                          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF64748B)),
                          dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                          items: [
                            DropdownMenuItem<String?>(
                              value: null,
                              child: Text('All Fleet Riders', style: GoogleFonts.inter(fontSize: 12, color: isDark ? Colors.white : const Color(0xFF0F172A)), overflow: TextOverflow.ellipsis),
                            ),
                            ...uniqueRiders.entries.map((e) {
                              return DropdownMenuItem<String?>(
                                value: e.key,
                                child: Text('🚴 ${e.value} (${e.key})', style: GoogleFonts.inter(fontSize: 12, color: isDark ? Colors.white : const Color(0xFF0F172A)), overflow: TextOverflow.ellipsis),
                              );
                            }),
                          ],
                          onChanged: (val) {
                            ref.read(dcOrderMatchingPageProvider.notifier).state = 1;
                            ref.read(dcOrderMatchingRiderFilterProvider.notifier).state = val;
                          },
                        ),
                      ),
                    );

                    final filterChips = SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: [
                          _buildFilterChip('all', 'All Remittances (${allLifecycleItems.length})', Icons.dashboard_rounded),
                          const SizedBox(width: 8),
                          _buildFilterChip('not_remitted', '⚠️ Not Remitted (${notRemittedItems.length})', Icons.warning_amber_rounded, color: const Color(0xFFF59E0B)),
                          const SizedBox(width: 8),
                          _buildFilterChip('remitted', '✅ Remitted & Cleared (${remittedItems.length})', Icons.check_circle_rounded, color: const Color(0xFF10B981)),
                          const SizedBox(width: 8),
                          _buildFilterChip('direct_paystack', '⚡ Direct Paystack (${directPaystackItems.length})', Icons.bolt_rounded, color: const Color(0xFF00A2D3)),
                        ],
                      ),
                    );

                    final viewSwitcher = Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildViewToggleBtn(
                            icon: Icons.table_chart_rounded,
                            label: 'Table',
                            isSelected: isTableView,
                            isDark: isDark,
                            onTap: () => ref.read(dcOrderMatchingTableViewProvider.notifier).state = true,
                          ),
                          _buildViewToggleBtn(
                            icon: Icons.grid_view_rounded,
                            label: 'Cards',
                            isSelected: !isTableView,
                            isDark: isDark,
                            onTap: () => ref.read(dcOrderMatchingTableViewProvider.notifier).state = false,
                          ),
                        ],
                      ),
                    );

                    if (isNarrow) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          searchBox,
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(child: dateDropdown),
                              const SizedBox(width: 8),
                              Expanded(child: riderDropdown),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(child: filterChips),
                              const SizedBox(width: 8),
                              viewSwitcher,
                            ],
                          ),
                        ],
                      );
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(flex: 5, child: searchBox),
                            const SizedBox(width: 10),
                            SizedBox(width: 170, child: dateDropdown),
                            const SizedBox(width: 10),
                            SizedBox(width: 200, child: riderDropdown),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(child: filterChips),
                            const SizedBox(width: 12),
                            viewSwitcher,
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 4. Data Table / Cards View (RepaintBoundary)
            RepaintBoundary(
              child: filteredItems.isEmpty
                  ? Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(40),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.rule_folder_outlined, size: 48, color: const Color(0xFF64748B).withValues(alpha: 0.5)),
                          const SizedBox(height: 12),
                          Text(
                            'No remittances matching the selected filter criteria',
                            style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : const Color(0xFF334155)),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Try selecting "All Remittances" or changing the date opening filter.',
                            style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isTableView)
                          _buildRemittancesTableView(pagedItems, isDark, isMobile)
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: pagedItems.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 12),
                            itemBuilder: (ctx, index) {
                              final item = pagedItems[index];
                              return _buildRemittanceLifecycleCard(item, isDark, isMobile);
                            },
                          ),
                        const SizedBox(height: 12),

                        // 5. Pagination Bar
                        _buildPaginationControls(
                          currentPage: safePage,
                          totalPages: totalPages,
                          totalItems: filteredItems.length,
                          startIndex: startIndex,
                          endIndex: endIndex,
                          rowsPerPage: rowsPerPage,
                          isDark: isDark,
                          isMobile: isMobile,
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required String subtext,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required Color borderColor,
    required double width,
    required bool isDark,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w700, color: const Color(0xFF64748B), letterSpacing: 0.5),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.jetBrainsMono(fontSize: 18, fontWeight: FontWeight.w900, color: isDark ? Colors.white : const Color(0xFF0F172A)),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            subtext,
            style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String key, String label, IconData icon, {Color? color}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedFilter = ref.watch(dcOrderMatchingFilterProvider);
    final isSelected = selectedFilter == key;
    final chipColor = color ?? const Color(0xFFF37021);

    return InkWell(
      onTap: () {
        ref.read(dcOrderMatchingPageProvider.notifier).state = 1;
        ref.read(dcOrderMatchingFilterProvider.notifier).state = key;
      },
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? chipColor.withValues(alpha: 0.15)
              : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? chipColor : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isSelected ? chipColor : const Color(0xFF64748B)),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? chipColor : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildViewToggleBtn({
    required IconData icon,
    required String label,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF37021) : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? Colors.white : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // TABLE VIEW IMPLEMENTATION
  // ==========================================

  Widget _buildRemittancesTableView(
    List<DCRemittanceLifecycleItem> items,
    bool isDark,
    bool isMobile,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 1050),
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
              dataRowMinHeight: 56,
              dataRowMaxHeight: 68,
              horizontalMargin: 16,
              columnSpacing: 22,
              columns: [
                _buildTableColumnHeader('RIDER / AGENT', Icons.badge_outlined, isDark),
                _buildTableColumnHeader('ORDERS', Icons.inventory_2_outlined, isDark),
                _buildTableColumnHeader('AMOUNT TO REMIT', Icons.payments_outlined, isDark),
                _buildTableColumnHeader('NET REMITTANCE', Icons.account_balance_wallet_outlined, isDark),
                _buildTableColumnHeader('PAYMENT METHOD', Icons.credit_card_outlined, isDark),
                _buildTableColumnHeader('OPENING DATE', Icons.schedule_rounded, isDark),
                _buildTableColumnHeader('CLOSING DATE', Icons.event_available_rounded, isDark),
                _buildTableColumnHeader('REMITTANCE STATUS', Icons.rule_rounded, isDark),
                _buildTableColumnHeader('ACTION', Icons.tune_rounded, isDark),
              ],
              rows: items.map((item) {
                return _buildDataRow(item, isDark);
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  DataColumn _buildTableColumnHeader(String label, IconData icon, bool isDark) {
    return DataColumn(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF64748B)),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  DataRow _buildDataRow(DCRemittanceLifecycleItem item, bool isDark) {
    final isDirect = item.isDirectTransfer;

    return DataRow(
      onSelectChanged: (_) {
        showDialog(
          context: context,
          builder: (ctx) => DCRemittanceDetailModal(remittance: item),
        );
      },
      cells: [
        // 1. Rider / Agent (Interactive tap to open DCRiderDetailModal)
        DataCell(
          InkWell(
            onTap: () => _openRiderProfile(item),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  UserAvatarWidget(
                    avatarUrl: item.riderAvatarUrl,
                    fullName: item.riderName,
                    radius: 16,
                    showBorder: true,
                    borderColor: item.isVerified ? const Color(0xFF10B981) : const Color(0xFFF37021),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            item.riderName,
                            style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.open_in_new_rounded, size: 11, color: Color(0xFF94A3B8)),
                        ],
                      ),
                      Text(
                        item.riderCode,
                        style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.w500, color: const Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),

        // 2. Orders (Count & Reference badge)
        DataCell(
          InkWell(
            onTap: () {
              showDialog(
                context: context,
                builder: (ctx) => DCRemittanceDetailModal(remittance: item),
              );
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.25)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.inventory_2_rounded, size: 13, color: Color(0xFF2563EB)),
                  const SizedBox(width: 5),
                  Text(
                    '${item.orderCount} ${item.orderCount == 1 ? 'Order' : 'Orders'}',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF2563EB),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // 3. Amount to Remit (Gross Figure Only)
        DataCell(
          Text(
            CurrencyFormatter.formatNaira(item.grossAmount),
            style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A)),
          ),
        ),

        // 4. Net Remittance (Net Figure Only)
        DataCell(
          Text(
            CurrencyFormatter.formatNaira(item.netAmount),
            style: GoogleFonts.jetBrainsMono(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: item.isVerified ? const Color(0xFF10B981) : (isDirect ? const Color(0xFF00A2D3) : const Color(0xFFF59E0B)),
            ),
          ),
        ),

        // 5. Payment Method
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isDirect ? Icons.bolt_rounded : Icons.payments_rounded,
                size: 14,
                color: isDirect ? const Color(0xFF00A2D3) : const Color(0xFFF59E0B),
              ),
              const SizedBox(width: 6),
              Text(
                isDirect ? 'Direct Transfer' : 'Cash POD',
                style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w500, color: isDark ? Colors.white70 : const Color(0xFF334155)),
              ),
            ],
          ),
        ),

        // 6. Opening Date
        DataCell(
          Text(
            _formatDateShort(item.openingDate),
            style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
          ),
        ),

        // 7. Closing Date
        DataCell(
          Text(
            item.closingDate != null ? _formatDateShort(item.closingDate!) : 'Active (Open)',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: item.closingDate != null ? FontWeight.w500 : FontWeight.bold,
              color: item.closingDate != null ? const Color(0xFF64748B) : const Color(0xFFF59E0B),
            ),
          ),
        ),

        // 8. Remittance Status (Not Remitted vs Remitted vs Direct Settled)
        DataCell(
          _buildStatusBadge(item.status),
        ),

        // 9. Action Button
        DataCell(
          ElevatedButton(
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => DCRemittanceDetailModal(remittance: item),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF37021).withValues(alpha: 0.12),
              foregroundColor: const Color(0xFFF37021),
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('View', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // CARDS VIEW IMPLEMENTATION
  // ==========================================

  Widget _buildRemittanceLifecycleCard(
    DCRemittanceLifecycleItem item,
    bool isDark,
    bool isMobile,
  ) {
    final isDirect = item.isDirectTransfer;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: !item.isVerified && !isDirect
              ? const Color(0xFFF59E0B).withValues(alpha: 0.4)
              : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          width: !item.isVerified && !isDirect ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            showDialog(
              context: context,
              builder: (ctx) => DCRemittanceDetailModal(remittance: item),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Meta: Rider & Status
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: () => _openRiderProfile(item),
                      borderRadius: BorderRadius.circular(20),
                      child: UserAvatarWidget(
                        avatarUrl: item.riderAvatarUrl,
                        fullName: item.riderName,
                        radius: 20,
                        showBorder: true,
                        borderColor: item.isVerified ? const Color(0xFF10B981) : const Color(0xFFF37021),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        onTap: () => _openRiderProfile(item),
                        borderRadius: BorderRadius.circular(6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    item.riderName,
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '${item.orderCount} ${item.orderCount == 1 ? 'Order' : 'Orders'}',
                                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF2563EB)),
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              'Driver Code: ${item.riderCode} • Ref: ${item.referenceNumber}',
                              style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                    ),
                    _buildStatusBadge(item.status),
                  ],
                ),
                const Divider(height: 22),

                // Financial Figures Grid
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('AMOUNT TO REMIT', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF64748B))),
                        const SizedBox(height: 2),
                        Text(
                          CurrencyFormatter.formatNaira(item.grossAmount),
                          style: GoogleFonts.jetBrainsMono(fontSize: 15, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('NET REMITTANCE', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF64748B))),
                        const SizedBox(height: 2),
                        Text(
                          CurrencyFormatter.formatNaira(item.netAmount),
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: item.isVerified ? const Color(0xFF10B981) : (isDirect ? const Color(0xFF00A2D3) : const Color(0xFFF59E0B)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Bottom Meta: Timestamps & Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.schedule_rounded, size: 13, color: Color(0xFF94A3B8)),
                        const SizedBox(width: 4),
                        Text(
                          'Opened: ${_formatDateShort(item.openingDate)}',
                          style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        if (!item.isVerified && !isDirect && item.orders.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.phone_in_talk_rounded, size: 16, color: Color(0xFFF37021)),
                            tooltip: 'Contact Rider to Remit',
                            onPressed: () {
                              DCContactRiderModal.show(
                                context: context,
                                order: item.orders.first,
                                riderName: item.riderName,
                                riderCode: item.riderCode,
                                riderPhone: item.riderPhone ?? '08031234567',
                                riderId: item.riderId,
                                amountAwaitingRemittance: item.netAmount,
                              );
                            },
                          ),
                        TextButton.icon(
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (ctx) => DCRemittanceDetailModal(remittance: item),
                            );
                          },
                          icon: const Icon(Icons.arrow_forward_rounded, size: 14),
                          label: const Text('View Breakdown'),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFFF37021),
                            textStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // PAGINATION CONTROLS
  // ==========================================

  Widget _buildPaginationControls({
    required int currentPage,
    required int totalPages,
    required int totalItems,
    required int startIndex,
    required int endIndex,
    required int rowsPerPage,
    required bool isDark,
    required bool isMobile,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Range Label & Rows Per Page Dropdown
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Showing ${totalItems == 0 ? 0 : startIndex + 1}–$endIndex of $totalItems',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
              ),
              if (!isMobile) ...[
                const SizedBox(width: 14),
                Text('Rows per page:', style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF94A3B8))),
                const SizedBox(width: 6),
                DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: rowsPerPage,
                    isDense: true,
                    dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                    items: const [
                      DropdownMenuItem(value: 10, child: Text('10')),
                      DropdownMenuItem(value: 15, child: Text('15')),
                      DropdownMenuItem(value: 25, child: Text('25')),
                      DropdownMenuItem(value: 50, child: Text('50')),
                      DropdownMenuItem(value: 100, child: Text('100')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        ref.read(dcOrderMatchingPageProvider.notifier).state = 1;
                        ref.read(dcOrderMatchingRowsPerPageProvider.notifier).state = val;
                      }
                    },
                  ),
                ),
              ],
            ],
          ),

          // Prev / Next Page Buttons
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded, size: 20),
                tooltip: 'Previous Page',
                onPressed: currentPage > 1
                    ? () => ref.read(dcOrderMatchingPageProvider.notifier).state = currentPage - 1
                    : null,
                color: const Color(0xFFF37021),
                disabledColor: const Color(0xFF94A3B8).withValues(alpha: 0.3),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Page $currentPage of $totalPages',
                  style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded, size: 20),
                tooltip: 'Next Page',
                onPressed: currentPage < totalPages
                    ? () => ref.read(dcOrderMatchingPageProvider.notifier).state = currentPage + 1
                    : null,
                color: const Color(0xFFF37021),
                disabledColor: const Color(0xFF94A3B8).withValues(alpha: 0.3),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final bool isNotRemitted = status == 'awaiting_remittance' || status == 'not_remitted';
    final bool isDirect = status == 'direct_settled';

    final Color badgeColor = isNotRemitted
        ? const Color(0xFFF59E0B)
        : (isDirect ? const Color(0xFF00A2D3) : const Color(0xFF10B981));
    final String label = isNotRemitted
        ? 'NOT REMITTED'
        : (isDirect ? 'DIRECT SETTLED' : 'REMITTED & CLEARED');
    final IconData icon = isNotRemitted
        ? Icons.hourglass_top_rounded
        : (isDirect ? Icons.bolt_rounded : Icons.check_circle_rounded);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: badgeColor),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.bold, color: badgeColor),
          ),
        ],
      ),
    );
  }
}
