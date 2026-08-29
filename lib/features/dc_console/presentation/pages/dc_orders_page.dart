import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/helpers/formatters.dart';
import '../../../../core/widgets/app_skeleton_loader.dart';
import '../../../orders/domain/entities/order.dart';
import '../../../orders/presentation/providers/orders_provider.dart';
import '../../../stock/presentation/providers/stock_provider.dart';
import '../../domain/entities/dc_fleet_driver.dart';
import '../providers/dc_console_provider.dart';
import '../widgets/dc_create_order_modal.dart';
import '../widgets/dc_order_detail_modal.dart';
import '../widgets/dc_csv_order_import_modal.dart';
import '../widgets/dc_assign_order_modal.dart';

final dcOrdersDateFilterProvider = StateProvider.autoDispose<String>((ref) => 'all_time');
final dcOrdersCustomDateRangeProvider = StateProvider.autoDispose<DateTimeRange?>((ref) => null);
final dcOrdersSingleDateProvider = StateProvider.autoDispose<DateTime?>((ref) => null);

// Master Orders Directory Multi-Attribute Filters
final dcMasterSearchProvider = StateProvider.autoDispose<String>((ref) => '');
final dcMasterStatusFilterProvider = StateProvider.autoDispose<String>((ref) => 'all');
final dcMasterRemittanceFilterProvider = StateProvider.autoDispose<String>((ref) => 'all');
final dcMasterRiderFilterProvider = StateProvider.autoDispose<String>((ref) => 'all');
final dcMasterProductFilterProvider = StateProvider.autoDispose<String>((ref) => 'all');
final dcMasterClientFilterProvider = StateProvider.autoDispose<String>((ref) => 'all');
final dcMasterViewModeProvider = StateProvider.autoDispose<String>((ref) => 'table');

class DCOrdersPage extends ConsumerStatefulWidget {
  const DCOrdersPage({super.key});

  @override
  ConsumerState<DCOrdersPage> createState() => _DCOrdersPageState();
}

class _DCOrdersPageState extends ConsumerState<DCOrdersPage> {
  final TextEditingController _masterSearchController = TextEditingController();
  Timer? _searchDebounceTimer;
  int _masterCurrentPage = 0;
  int _masterPageSize = 25;

  void _onDebouncedSearch(void Function() action) {
    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = Timer(const Duration(milliseconds: 250), () {
      if (mounted) {
        action();
      }
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(ordersProvider.notifier).loadDcOrders('22222222-2222-4222-8222-222222222222');
    });
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    _masterSearchController.dispose();
    super.dispose();
  }

  List<OrderEntity> _filterOrdersByDate(
    List<OrderEntity> orders,
    String dateFilter,
    DateTimeRange? customRange,
    DateTime? singleDate,
  ) {
    if (dateFilter == 'all_time') return orders;
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);

    return orders.where((o) {
      final date = o.createdAt;
      switch (dateFilter) {
        case 'today':
          return date.isAfter(todayStart) && date.isBefore(todayEnd);
        case 'yesterday':
          final yesterdayStart = todayStart.subtract(const Duration(days: 1));
          final yesterdayEnd = todayStart.subtract(const Duration(seconds: 1));
          return date.isAfter(yesterdayStart) && date.isBefore(yesterdayEnd);
        case 'this_week':
          final weekStart = todayStart.subtract(Duration(days: now.weekday - 1));
          return date.isAfter(weekStart);
        case 'this_month':
          final monthStart = DateTime(now.year, now.month, 1);
          return date.isAfter(monthStart);
        case 'single_date':
          if (singleDate == null) return true;
          return date.year == singleDate.year &&
                 date.month == singleDate.month &&
                 date.day == singleDate.day;
        case 'custom':
          if (customRange == null) return true;
          final start = DateTime(customRange.start.year, customRange.start.month, customRange.start.day);
          final end = DateTime(customRange.end.year, customRange.end.month, customRange.end.day, 23, 59, 59);
          return (date.isAfter(start) || date.isAtSameMomentAs(start)) &&
                 (date.isBefore(end) || date.isAtSameMomentAs(end));
        default:
          return true;
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final ordersState = ref.watch(ordersProvider);
    final dcState = ref.watch(dcConsoleProvider);
    final activeDateFilter = ref.watch(dcOrdersDateFilterProvider);
    final customRange = ref.watch(dcOrdersCustomDateRangeProvider);
    final singleDate = ref.watch(dcOrdersSingleDateProvider);

    final dateFilteredOrders = _filterOrdersByDate(ordersState.orders, activeDateFilter, customRange, singleDate);

    final unassignedOrders = dateFilteredOrders.where((o) {
      final isUnassigned = o.deliveryAgentId == null || o.deliveryAgentId!.isEmpty;
      return isUnassigned && o.status != 'delivered' && o.status != 'cancelled' && o.status != 'failed';
    }).toList();

    final inTransitOrders = dateFilteredOrders.where((o) {
      final isAssigned = o.deliveryAgentId != null && o.deliveryAgentId!.isNotEmpty;
      return isAssigned && o.status != 'delivered' && o.status != 'cancelled' && o.status != 'failed';
    }).toList();

    final deliveredOrders = dateFilteredOrders.where((o) => o.status == 'delivered').toList();
    final failedOrders = dateFilteredOrders.where((o) => o.status == 'cancelled' || o.status == 'failed' || o.status == 'call_back' || o.status == 'returned').toList();

    return SafeArea(
      child: Material(
        color: Colors.transparent,
        child: _buildAllOrdersView(
          isDark,
          dateFilteredOrders,
          dcState,
          ordersState,
          unassignedOrders.length,
          inTransitOrders.length,
          deliveredOrders.length,
          failedOrders.length,
        ),
      ),
    );
  }

  Widget _buildDateFilterPopupButton({
    required BuildContext context,
    required bool isDark,
    required String activeDateFilter,
    required DateTimeRange? customRange,
    required DateTime? singleDate,
    bool iconOnly = false,
  }) {
    String label = 'All Time';
    bool isCustomActive = activeDateFilter != 'all_time';

    if (activeDateFilter == 'today') {
      label = 'Today';
    } else if (activeDateFilter == 'yesterday') {
      label = 'Yesterday';
    } else if (activeDateFilter == 'this_week') {
      label = 'This Week';
    } else if (activeDateFilter == 'this_month') {
      label = 'This Month';
    } else if (activeDateFilter == 'single_date' && singleDate != null) {
      label = DateTimeFormatter.formatShortDate(singleDate);
    } else if (activeDateFilter == 'custom' && customRange != null) {
      label = '${customRange.start.day}/${customRange.start.month} - ${customRange.end.day}/${customRange.end.month}';
    }

    return PopupMenuButton<String>(
      tooltip: 'Filter Orders by Date',
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (choice) async {
        if (choice == 'custom') {
          final picked = await showDateRangePicker(
            context: context,
            firstDate: DateTime(2025, 1, 1),
            lastDate: DateTime(2030, 12, 31),
            initialDateRange: customRange ??
                DateTimeRange(
                  start: DateTime.now().subtract(const Duration(days: 7)),
                  end: DateTime.now(),
                ),
            helpText: 'SELECT ORDER DATE RANGE',
            cancelText: 'CANCEL',
            confirmText: 'APPLY FILTER',
            saveText: 'APPLY',
            builder: (context, child) {
              return Theme(
                data: Theme.of(context).copyWith(
                  colorScheme: isDark
                      ? const ColorScheme.dark(
                          primary: Color(0xFFF37021),
                          onPrimary: Colors.white,
                          surface: Color(0xFF1E293B),
                          onSurface: Colors.white,
                          secondary: Color(0xFF2563EB),
                        )
                      : const ColorScheme.light(
                          primary: Color(0xFFF37021),
                          onPrimary: Colors.white,
                          surface: Colors.white,
                          onSurface: Color(0xFF0F172A),
                          secondary: Color(0xFF2563EB),
                        ),
                  dialogBackgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                ),
                child: child!,
              );
            },
          );
          if (picked != null) {
            ref.read(dcOrdersCustomDateRangeProvider.notifier).state = picked;
            ref.read(dcOrdersSingleDateProvider.notifier).state = null;
            ref.read(dcOrdersDateFilterProvider.notifier).state = 'custom';
          }
        } else if (choice == 'single_date') {
          final picked = await showDatePicker(
            context: context,
            firstDate: DateTime(2025, 1, 1),
            lastDate: DateTime(2030, 12, 31),
            initialDate: singleDate ?? DateTime.now(),
            helpText: 'SELECT ORDER DATE',
            cancelText: 'CANCEL',
            confirmText: 'APPLY FILTER',
            builder: (context, child) {
              return Theme(
                data: Theme.of(context).copyWith(
                  colorScheme: isDark
                      ? const ColorScheme.dark(
                          primary: Color(0xFFF37021),
                          onPrimary: Colors.white,
                          surface: Color(0xFF1E293B),
                          onSurface: Colors.white,
                        )
                      : const ColorScheme.light(
                          primary: Color(0xFFF37021),
                          onPrimary: Colors.white,
                          surface: Colors.white,
                          onSurface: Color(0xFF0F172A),
                        ),
                  dialogBackgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                ),
                child: child!,
              );
            },
          );
          if (picked != null) {
            ref.read(dcOrdersSingleDateProvider.notifier).state = picked;
            ref.read(dcOrdersCustomDateRangeProvider.notifier).state = null;
            ref.read(dcOrdersDateFilterProvider.notifier).state = 'single_date';
          }
        } else {
          ref.read(dcOrdersDateFilterProvider.notifier).state = choice;
          ref.read(dcOrdersCustomDateRangeProvider.notifier).state = null;
          ref.read(dcOrdersSingleDateProvider.notifier).state = null;
        }
      },
      constraints: const BoxConstraints(minWidth: 260, maxWidth: 330),
      itemBuilder: (ctx) => [
        _buildDateMenuItem('all_time', 'All Time', activeDateFilter == 'all_time', Icons.all_inclusive_rounded, isDark),
        _buildDateMenuItem('today', 'Today', activeDateFilter == 'today', Icons.today_rounded, isDark),
        _buildDateMenuItem('yesterday', 'Yesterday', activeDateFilter == 'yesterday', Icons.history_rounded, isDark),
        _buildDateMenuItem('this_week', 'This Week', activeDateFilter == 'this_week', Icons.date_range_rounded, isDark),
        _buildDateMenuItem('this_month', 'This Month', activeDateFilter == 'this_month', Icons.calendar_view_month_rounded, isDark),
        const PopupMenuDivider(),
        _buildDateMenuItem('single_date', 'Single Date (Calendar Pop-up)...', activeDateFilter == 'single_date', Icons.event_available_rounded, isDark),
        _buildDateMenuItem('custom', 'Custom Range (From - To Calendar)...', activeDateFilter == 'custom', Icons.date_range_outlined, isDark),
      ],
      child: iconOnly
          ? Container(
              height: 38,
              width: 42,
              decoration: BoxDecoration(
                color: isCustomActive
                    ? const Color(0xFFF37021).withValues(alpha: 0.14)
                    : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isCustomActive
                      ? const Color(0xFFF37021)
                      : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                  width: isCustomActive ? 1.5 : 1.0,
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    Icons.calendar_month_rounded,
                    size: 18,
                    color: isCustomActive
                        ? const Color(0xFFF37021)
                        : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                  ),
                  if (isCustomActive)
                    Positioned(
                      top: 5,
                      right: 5,
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Color(0xFFF37021),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            )
          : Container(
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isCustomActive
                    ? const Color(0xFFF37021).withValues(alpha: 0.12)
                    : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isCustomActive
                      ? const Color(0xFFF37021)
                      : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.calendar_month_rounded,
                    size: 14,
                    color: isCustomActive ? const Color(0xFFF37021) : const Color(0xFF64748B),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Date: $label',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: isCustomActive ? FontWeight.bold : FontWeight.w500,
                      color: isCustomActive
                          ? const Color(0xFFF37021)
                          : (isDark ? Colors.white : const Color(0xFF0F172A)),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_drop_down_rounded,
                    size: 18,
                    color: isCustomActive ? const Color(0xFFF37021) : const Color(0xFF64748B),
                  ),
                ],
              ),
            ),
    );
  }

  PopupMenuItem<String> _buildDateMenuItem(String value, String title, bool isSelected, IconData icon, bool isDark) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: isSelected ? const Color(0xFFF37021) : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? const Color(0xFFF37021) : (isDark ? Colors.white : const Color(0xFF0F172A)),
              ),
            ),
          ),
          if (isSelected) ...[
            const SizedBox(width: 6),
            const Icon(Icons.check_rounded, size: 16, color: Color(0xFFF37021)),
          ],
        ],
      ),
    );
  }

  Widget _buildMobileIconPopupFilter({
    required BuildContext context,
    required bool isDark,
    required IconData icon,
    required String tooltip,
    required String currentValue,
    required ValueChanged<String> onSelected,
    required List<PopupMenuEntry<String>> items,
  }) {
    final isFiltered = currentValue != 'all';
    return PopupMenuButton<String>(
      tooltip: tooltip,
      onSelected: onSelected,
      constraints: const BoxConstraints(minWidth: 220, maxWidth: 300),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      itemBuilder: (ctx) => items,
      child: Container(
        height: 38,
        width: 42,
        decoration: BoxDecoration(
          color: isFiltered
              ? const Color(0xFFF37021).withValues(alpha: 0.14)
              : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isFiltered
                ? const Color(0xFFF37021)
                : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
            width: isFiltered ? 1.5 : 1.0,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isFiltered
                  ? const Color(0xFFF37021)
                  : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
            ),
            if (isFiltered)
              Positioned(
                top: 5,
                right: 5,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF37021),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileIconFilterBar({
    required BuildContext context,
    required bool isDark,
    required String activeDateFilter,
    required DateTimeRange? customRange,
    required DateTime? singleDate,
    required String masterStatus,
    required String masterRemittance,
    required String masterRider,
    required String masterProduct,
    required String masterClient,
    required List<DCFleetDriver> fleetDrivers,
    required List<String> uniqueProducts,
    required List<String> uniqueClients,
    required bool hasActiveFilters,
  }) {
    final dateBtn = _buildDateFilterPopupButton(
      context: context,
      isDark: isDark,
      activeDateFilter: activeDateFilter,
      customRange: customRange,
      singleDate: singleDate,
      iconOnly: true,
    );

    final statusBtn = _buildMobileIconPopupFilter(
      context: context,
      isDark: isDark,
      icon: Icons.filter_list_rounded,
      tooltip: 'Status Filter ($masterStatus)',
      currentValue: masterStatus,
      onSelected: (val) => ref.read(dcMasterStatusFilterProvider.notifier).state = val,
      items: const [
        PopupMenuItem(value: 'all', child: Text('All Statuses')),
        PopupMenuItem(value: 'unassigned', child: Text('📦 Unassigned (Pending)')),
        PopupMenuItem(value: 'in_transit', child: Text('🚴 In Transit (Assigned)')),
        PopupMenuItem(value: 'delivered', child: Text('🟢 Delivered (All Fulfilled)')),
        PopupMenuItem(value: 'awaiting_remittance', child: Text('🟡 Delivered (Cash in Custody • Awaiting Remittance)')),
        PopupMenuItem(value: 'remitted', child: Text('🟢 Delivered (Remitted & Cleared)')),
        PopupMenuItem(value: 'failed', child: Text('⚠️ Failed / Call Back')),
        PopupMenuItem(value: 'returned', child: Text('↩️ Returned to DC')),
      ],
    );

    final remittanceBtn = _buildMobileIconPopupFilter(
      context: context,
      isDark: isDark,
      icon: Icons.payments_outlined,
      tooltip: 'Cash / Remittance ($masterRemittance)',
      currentValue: masterRemittance,
      onSelected: (val) => ref.read(dcMasterRemittanceFilterProvider.notifier).state = val,
      items: const [
        PopupMenuItem(value: 'all', child: Text('All Settlements')),
        PopupMenuItem(value: 'awaiting_remittance', child: Text('🟡 Cash in Custody (Awaiting Remittance)')),
        PopupMenuItem(value: 'remitted', child: Text('🟢 Remitted & Cleared')),
        PopupMenuItem(value: 'direct_transfer', child: Text('⚡ Direct Transfer / Bank')),
        PopupMenuItem(value: 'pending_fulfillment', child: Text('🕒 Pending Delivery')),
      ],
    );

    final riderBtn = _buildMobileIconPopupFilter(
      context: context,
      isDark: isDark,
      icon: Icons.two_wheeler_rounded,
      tooltip: 'Rider Filter ($masterRider)',
      currentValue: masterRider,
      onSelected: (val) => ref.read(dcMasterRiderFilterProvider.notifier).state = val,
      items: [
        const PopupMenuItem(value: 'all', child: Text('All Riders')),
        const PopupMenuItem(value: 'unassigned', child: Text('📦 Unassigned Only')),
        ...fleetDrivers.map((d) {
          return PopupMenuItem(
            value: d.id,
            child: Text('🚴 ${d.name} (${d.driverCode})'),
          );
        }),
      ],
    );

    final productBtn = _buildMobileIconPopupFilter(
      context: context,
      isDark: isDark,
      icon: Icons.inventory_2_outlined,
      tooltip: 'Product Filter ($masterProduct)',
      currentValue: masterProduct,
      onSelected: (val) => ref.read(dcMasterProductFilterProvider.notifier).state = val,
      items: [
        const PopupMenuItem(value: 'all', child: Text('All Products')),
        ...uniqueProducts.map((p) {
          return PopupMenuItem(
            value: p,
            child: Text(p),
          );
        }),
      ],
    );

    final clientBtn = _buildMobileIconPopupFilter(
      context: context,
      isDark: isDark,
      icon: Icons.business_rounded,
      tooltip: 'Client Filter ($masterClient)',
      currentValue: masterClient,
      onSelected: (val) => ref.read(dcMasterClientFilterProvider.notifier).state = val,
      items: [
        const PopupMenuItem(value: 'all', child: Text('All Clients')),
        ...uniqueClients.map((c) {
          return PopupMenuItem(
            value: c,
            child: Text(c),
          );
        }),
      ],
    );

    Widget? resetBtn;
    if (hasActiveFilters) {
      resetBtn = Tooltip(
        message: 'Reset All Filters',
        child: InkWell(
          onTap: () {
            _masterSearchController.clear();
            ref.read(dcMasterSearchProvider.notifier).state = '';
            ref.read(dcMasterStatusFilterProvider.notifier).state = 'all';
            ref.read(dcMasterRemittanceFilterProvider.notifier).state = 'all';
            ref.read(dcMasterRiderFilterProvider.notifier).state = 'all';
            ref.read(dcMasterProductFilterProvider.notifier).state = 'all';
            ref.read(dcMasterClientFilterProvider.notifier).state = 'all';
            ref.read(dcOrdersDateFilterProvider.notifier).state = 'all_time';
            ref.read(dcOrdersCustomDateRangeProvider.notifier).state = null;
            ref.read(dcOrdersSingleDateProvider.notifier).state = null;
          },
          borderRadius: BorderRadius.circular(10),
          child: Container(
            height: 38,
            width: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.4)),
            ),
            child: const Center(
              child: Icon(Icons.restart_alt_rounded, size: 18, color: Color(0xFFEF4444)),
            ),
          ),
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        dateBtn,
        statusBtn,
        remittanceBtn,
        riderBtn,
        productBtn,
        clientBtn,
        if (resetBtn != null) resetBtn,
      ],
    );
  }

  // ==========================================
  // 0. MASTER ALL ORDERS DIRECTORY VIEW
  // ==========================================

  Widget _buildAllOrdersView(
    bool isDark,
    List<OrderEntity> allOrders,
    DCConsoleState dcState,
    OrdersState ordersState,
    int unassignedCount,
    int inTransitCount,
    int deliveredCount,
    int failedCount,
  ) {
    final masterSearch = ref.watch(dcMasterSearchProvider).trim().toLowerCase();
    final masterStatus = ref.watch(dcMasterStatusFilterProvider);
    final masterRemittance = ref.watch(dcMasterRemittanceFilterProvider);
    final masterRider = ref.watch(dcMasterRiderFilterProvider);
    final masterProduct = ref.watch(dcMasterProductFilterProvider);
    final masterClient = ref.watch(dcMasterClientFilterProvider);
    final activeDateFilter = ref.watch(dcOrdersDateFilterProvider);
    final customRange = ref.watch(dcOrdersCustomDateRangeProvider);
    final singleDate = ref.watch(dcOrdersSingleDateProvider);
    final viewMode = ref.watch(dcMasterViewModeProvider);

    // Apply multi-attribute filters
    final filtered = allOrders.where((o) {
      // 1. Status Filter
      if (masterStatus != 'all') {
        if (masterStatus == 'unassigned') {
          final isUnassigned = o.deliveryAgentId == null || o.deliveryAgentId!.isEmpty;
          if (!isUnassigned || o.status == 'delivered' || o.status == 'cancelled' || o.status == 'failed') return false;
        } else if (masterStatus == 'in_transit') {
          final isAssigned = o.deliveryAgentId != null && o.deliveryAgentId!.isNotEmpty;
          if (!isAssigned || o.status == 'delivered' || o.status == 'cancelled' || o.status == 'failed') return false;
        } else if (masterStatus == 'delivered') {
          if (o.status != 'delivered') return false;
        } else if (masterStatus == 'awaiting_remittance' || masterStatus == 'delivered_unremitted') {
          final isCashAwaiting = o.status == 'delivered' && o.isUnremitted && !o.isDirectTransfer;
          if (!isCashAwaiting) return false;
        } else if (masterStatus == 'remitted' || masterStatus == 'delivered_remitted') {
          final isRemitted = o.status == 'delivered' && (o.isRemitted || o.isDirectTransfer);
          if (!isRemitted) return false;
        } else if (masterStatus == 'failed') {
          if (o.status != 'cancelled' && o.status != 'failed' && o.status != 'call_back') return false;
        } else if (masterStatus == 'returned') {
          if (o.status != 'returned') return false;
        }
      }

      // 2. Remittance / Cash Holding Filter
      if (masterRemittance != 'all') {
        if (masterRemittance == 'awaiting_remittance' || masterRemittance == 'unremitted') {
          final isCashAwaiting = o.isDelivered && o.isUnremitted && !o.isDirectTransfer;
          if (!isCashAwaiting) return false;
        } else if (masterRemittance == 'remitted') {
          final isCleared = o.isDelivered && o.isRemitted && !o.isDirectTransfer;
          if (!isCleared) return false;
        } else if (masterRemittance == 'direct_transfer') {
          final isDirect = o.isDirectTransfer;
          if (!isDirect) return false;
        } else if (masterRemittance == 'pending_fulfillment') {
          if (o.isDelivered) return false;
        }
      }

      // 3. Rider Filter
      if (masterRider != 'all') {
        if (masterRider == 'unassigned') {
          if (o.deliveryAgentId != null && o.deliveryAgentId!.isNotEmpty) return false;
        } else {
          final matchesId = o.deliveryAgentId == masterRider;
          final matchesCode = o.deliveryAgentCode == masterRider;
          final matchesName = o.deliveryAgentName != null && o.deliveryAgentName!.toLowerCase() == masterRider.toLowerCase();
          if (!matchesId && !matchesCode && !matchesName) return false;
        }
      }

      // 4. Product Filter
      if (masterProduct != 'all') {
        if (!o.productName.toLowerCase().contains(masterProduct.toLowerCase())) return false;
      }

      // 5. Client Filter
      if (masterClient != 'all') {
        final client = o.clientName.isNotEmpty ? o.clientName : 'Novacare';
        if (!client.toLowerCase().contains(masterClient.toLowerCase())) return false;
      }

      // 6. Search Query Filter
      if (masterSearch.isNotEmpty) {
        final matchesOrderNum = o.orderNumber.toLowerCase().contains(masterSearch);
        final matchesCust = o.customerName.toLowerCase().contains(masterSearch);
        final matchesPhone = o.customerPhone.toLowerCase().contains(masterSearch);
        final matchesAddress = o.deliveryAddress.toLowerCase().contains(masterSearch) || o.deliveryCity.toLowerCase().contains(masterSearch);
        final matchesProduct = o.productName.toLowerCase().contains(masterSearch);
        final matchesClient = o.clientName.toLowerCase().contains(masterSearch);
        final matchesRider = (o.deliveryAgentName != null && o.deliveryAgentName!.toLowerCase().contains(masterSearch)) ||
            (o.deliveryAgentCode != null && o.deliveryAgentCode!.toLowerCase().contains(masterSearch));

        if (!matchesOrderNum && !matchesCust && !matchesPhone && !matchesAddress && !matchesProduct && !matchesClient && !matchesRider) {
          return false;
        }
      }

      return true;
    }).toList();

    final double totalValuation = filtered.fold(0.0, (acc, o) => acc + o.totalAmount);
    final double deliveredRevenue = filtered.where((o) => o.status == 'delivered').fold(0.0, (acc, o) => acc + o.totalAmount);

    final unremittedOrders = allOrders.where((o) => o.status == 'delivered' && o.isUnremitted && !o.isDirectTransfer).toList();
    final int unremittedCount = unremittedOrders.length;
    final double unremittedCash = unremittedOrders.fold(0.0, (acc, o) => acc + o.totalAmount);

    // Extract dynamic dropdown items
    final uniqueProducts = allOrders.map((o) => o.productName).where((p) => p.isNotEmpty).toSet().toList()..sort();
    final uniqueClients = allOrders.map((o) => o.clientName).where((c) => c.isNotEmpty).toSet().toList()..sort();
    final fleetDrivers = dcState.drivers;

    final bool hasActiveFilters = masterSearch.isNotEmpty ||
        masterStatus != 'all' ||
        masterRemittance != 'all' ||
        masterRider != 'all' ||
        masterProduct != 'all' ||
        masterClient != 'all' ||
        activeDateFilter != 'all_time';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Summary KPI Metric Cards (6 Cards) - Compact & Horizontally Scrollable on Mobile
          LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth >= 1150;
              if (isDesktop) {
                final cardWidth = (constraints.maxWidth - 40) / 6;
                return Row(
                  children: [
                    _buildDeliveredKpiCard(
                      isDark,
                      title: 'Total Filtered Orders',
                      value: '${filtered.length} Orders',
                      subtitle: 'Gross: ${CurrencyFormatter.formatNaira(totalValuation)}',
                      icon: Icons.inventory_2_rounded,
                      iconColor: const Color(0xFF2563EB),
                      width: cardWidth,
                    ),
                    const SizedBox(width: 8),
                    _buildDeliveredKpiCard(
                      isDark,
                      title: '📦 Unassigned Pool',
                      value: '$unassignedCount Pending',
                      subtitle: 'Awaiting rider dispatch',
                      icon: Icons.outbox_rounded,
                      iconColor: const Color(0xFFF37021),
                      width: cardWidth,
                    ),
                    const SizedBox(width: 8),
                    _buildDeliveredKpiCard(
                      isDark,
                      title: '🚴 In-Transit Live',
                      value: '$inTransitCount Active',
                      subtitle: 'Out on delivery routes',
                      icon: Icons.local_shipping_rounded,
                      iconColor: const Color(0xFF0284C7),
                      width: cardWidth,
                    ),
                    const SizedBox(width: 8),
                    _buildDeliveredKpiCard(
                      isDark,
                      title: '🟢 Fulfilled / POD',
                      value: '$deliveredCount Delivered',
                      subtitle: 'Rev: ${CurrencyFormatter.formatNaira(deliveredRevenue)}',
                      icon: Icons.check_circle_rounded,
                      iconColor: const Color(0xFF16A34A),
                      width: cardWidth,
                    ),
                    const SizedBox(width: 8),
                    _buildDeliveredKpiCard(
                      isDark,
                      title: '🟡 Cash in Custody',
                      value: CurrencyFormatter.formatNaira(unremittedCash),
                      subtitle: '$unremittedCount awaiting remittance',
                      icon: Icons.payments_rounded,
                      iconColor: const Color(0xFFD97706),
                      width: cardWidth,
                      onTap: () {
                        ref.read(dcMasterStatusFilterProvider.notifier).state = 'awaiting_remittance';
                      },
                    ),
                    const SizedBox(width: 8),
                    _buildDeliveredKpiCard(
                      isDark,
                      title: '⚠️ Failed / Returns',
                      value: '$failedCount Issues',
                      subtitle: 'Call backs & returns',
                      icon: Icons.warning_amber_rounded,
                      iconColor: const Color(0xFFDC2626),
                      width: cardWidth,
                    ),
                  ],
                );
              }

              // On Mobile & Tablet: 1-line horizontal scrollable strip
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    _buildDeliveredKpiCard(
                      isDark,
                      title: 'Total Filtered Orders',
                      value: '${filtered.length} Orders',
                      subtitle: 'Gross: ${CurrencyFormatter.formatNaira(totalValuation)}',
                      icon: Icons.inventory_2_rounded,
                      iconColor: const Color(0xFF2563EB),
                      width: 175,
                    ),
                    const SizedBox(width: 8),
                    _buildDeliveredKpiCard(
                      isDark,
                      title: '📦 Unassigned Pool',
                      value: '$unassignedCount Pending',
                      subtitle: 'Awaiting rider dispatch',
                      icon: Icons.outbox_rounded,
                      iconColor: const Color(0xFFF37021),
                      width: 175,
                    ),
                    const SizedBox(width: 8),
                    _buildDeliveredKpiCard(
                      isDark,
                      title: '🚴 In-Transit Live',
                      value: '$inTransitCount Active',
                      subtitle: 'Out on delivery routes',
                      icon: Icons.local_shipping_rounded,
                      iconColor: const Color(0xFF0284C7),
                      width: 175,
                    ),
                    const SizedBox(width: 8),
                    _buildDeliveredKpiCard(
                      isDark,
                      title: '🟢 Fulfilled / POD',
                      value: '$deliveredCount Delivered',
                      subtitle: 'Rev: ${CurrencyFormatter.formatNaira(deliveredRevenue)}',
                      icon: Icons.check_circle_rounded,
                      iconColor: const Color(0xFF16A34A),
                      width: 175,
                    ),
                    const SizedBox(width: 8),
                    _buildDeliveredKpiCard(
                      isDark,
                      title: '🟡 Cash in Custody',
                      value: CurrencyFormatter.formatNaira(unremittedCash),
                      subtitle: '$unremittedCount awaiting remittance',
                      icon: Icons.payments_rounded,
                      iconColor: const Color(0xFFD97706),
                      width: 175,
                      onTap: () {
                        ref.read(dcMasterStatusFilterProvider.notifier).state = 'awaiting_remittance';
                      },
                    ),
                    const SizedBox(width: 8),
                    _buildDeliveredKpiCard(
                      isDark,
                      title: '⚠️ Failed / Returns',
                      value: '$failedCount Issues',
                      subtitle: 'Call backs & returns',
                      icon: Icons.warning_amber_rounded,
                      iconColor: const Color(0xFFDC2626),
                      width: 175,
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 14),

          // 2. Action Buttons
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (ctx) => const DCCreateOrderModal(),
                  );
                },
                icon: const Icon(Icons.add_rounded, size: 16, color: Colors.white),
                label: const Text('Create New Order', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12.5)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF37021),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (ctx) => const DCCsvOrderImportModal(),
                  );
                },
                icon: const Icon(Icons.upload_file_rounded, size: 16, color: Colors.white),
                label: const Text('Import CSV', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12.5)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              if (unassignedCount > 0)
                ElevatedButton.icon(
                  onPressed: () {
                    final unassignedList = allOrders.where((o) => (o.deliveryAgentId == null || o.deliveryAgentId!.isEmpty) && o.status != 'delivered').toList();
                    _autoAssignPool(unassignedList, dcState, ordersState);
                  },
                  icon: const Icon(Icons.auto_awesome, size: 16, color: Colors.white),
                  label: const Text('Auto-Assign Pool', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12.5)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // 3. Multi-Attribute Filter Toolbar Card
          Container(
            padding: const EdgeInsets.all(14),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Search & View Mode Switcher
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 42,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                        ),
                        child: TextField(
                          key: const Key('dc_master_search_input'),
                          controller: _masterSearchController,
                          onChanged: (val) {
                            _onDebouncedSearch(() {
                              ref.read(dcMasterSearchProvider.notifier).state = val;
                            });
                          },
                          style: GoogleFonts.inter(fontSize: 13, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                          decoration: InputDecoration(
                            hintText: 'Search by Order #, Customer Name, Phone, Address, Product, Client, or Rider...',
                            hintStyle: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF94A3B8)),
                            prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF64748B)),
                            suffixIcon: _masterSearchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear_rounded, size: 16),
                                    onPressed: () {
                                      _masterSearchController.clear();
                                      ref.read(dcMasterSearchProvider.notifier).state = '';
                                    },
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 11),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      height: 42,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: Icon(
                              Icons.table_chart_rounded,
                              size: 18,
                              color: viewMode == 'table' ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                            ),
                            tooltip: 'Table List View',
                            onPressed: () => ref.read(dcMasterViewModeProvider.notifier).state = 'table',
                          ),
                          Container(width: 1, height: 20, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                          IconButton(
                            icon: Icon(
                              Icons.grid_view_rounded,
                              size: 18,
                              color: viewMode == 'grid' ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                            ),
                            tooltip: 'Cards Grid View',
                            onPressed: () => ref.read(dcMasterViewModeProvider.notifier).state = 'grid',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Bottom Row: Adaptive Filters
                LayoutBuilder(
                  builder: (context, filterConstraints) {
                    final isCompact = filterConstraints.maxWidth < 700;
                    if (isCompact) {
                      return _buildMobileIconFilterBar(
                        context: context,
                        isDark: isDark,
                        activeDateFilter: activeDateFilter,
                        customRange: customRange,
                        singleDate: singleDate,
                        masterStatus: masterStatus,
                        masterRemittance: masterRemittance,
                        masterRider: masterRider,
                        masterProduct: masterProduct,
                        masterClient: masterClient,
                        fleetDrivers: fleetDrivers,
                        uniqueProducts: uniqueProducts,
                        uniqueClients: uniqueClients,
                        hasActiveFilters: hasActiveFilters,
                      );
                    }

                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: [
                          // 1. Pop-up Date Filter
                          _buildDateFilterPopupButton(
                            context: context,
                            isDark: isDark,
                            activeDateFilter: activeDateFilter,
                            customRange: customRange,
                            singleDate: singleDate,
                          ),
                          const SizedBox(width: 8),

                          // 2. Status Filter Dropdown
                          _buildFilterDropdown(
                            label: 'Status',
                            icon: Icons.filter_alt_outlined,
                            value: masterStatus,
                            isDark: isDark,
                            items: const [
                              DropdownMenuItem(value: 'all', child: Text('All Statuses')),
                              DropdownMenuItem(value: 'unassigned', child: Text('📦 Unassigned (Pending)')),
                              DropdownMenuItem(value: 'in_transit', child: Text('🚴 In Transit (Assigned)')),
                              DropdownMenuItem(value: 'delivered', child: Text('🟢 Delivered (All Fulfilled)')),
                              DropdownMenuItem(value: 'awaiting_remittance', child: Text('🟡 Delivered (Cash in Custody • Awaiting Remittance)')),
                              DropdownMenuItem(value: 'remitted', child: Text('🟢 Delivered (Remitted & Cleared)')),
                              DropdownMenuItem(value: 'failed', child: Text('⚠️ Failed / Call Back')),
                              DropdownMenuItem(value: 'returned', child: Text('↩️ Returned to DC')),
                            ],
                            onChanged: (val) {
                              if (val != null) ref.read(dcMasterStatusFilterProvider.notifier).state = val;
                            },
                          ),
                          const SizedBox(width: 8),

                          // 3. Remittance / Cash Holding Filter Dropdown
                          _buildFilterDropdown(
                            label: 'Remittance',
                            icon: Icons.payments_outlined,
                            value: masterRemittance,
                            isDark: isDark,
                            items: const [
                              DropdownMenuItem(value: 'all', child: Text('All Cash / Settlements')),
                              DropdownMenuItem(value: 'awaiting_remittance', child: Text('🟡 Cash in Custody (Awaiting Remittance)')),
                              DropdownMenuItem(value: 'remitted', child: Text('🟢 Remitted & Cleared')),
                              DropdownMenuItem(value: 'direct_transfer', child: Text('⚡ Direct Transfer / Bank')),
                              DropdownMenuItem(value: 'pending_fulfillment', child: Text('🕒 Pending Delivery')),
                            ],
                            onChanged: (val) {
                              if (val != null) ref.read(dcMasterRemittanceFilterProvider.notifier).state = val;
                            },
                          ),
                          const SizedBox(width: 8),

                          // 4. Rider Filter Dropdown
                          _buildFilterDropdown(
                            label: 'Rider',
                            icon: Icons.two_wheeler_rounded,
                            value: masterRider,
                            isDark: isDark,
                            items: [
                              const DropdownMenuItem(value: 'all', child: Text('All Riders')),
                              const DropdownMenuItem(value: 'unassigned', child: Text('📦 Unassigned Only')),
                              ...fleetDrivers.map((d) {
                                return DropdownMenuItem(
                                  value: d.id,
                                  child: Text('🚴 ${d.name} (${d.driverCode})'),
                                );
                              }),
                            ],
                            onChanged: (val) {
                              if (val != null) ref.read(dcMasterRiderFilterProvider.notifier).state = val;
                            },
                          ),
                          const SizedBox(width: 8),

                          // 5. Product Filter Dropdown
                          _buildFilterDropdown(
                            label: 'Product',
                            icon: Icons.inventory_2_outlined,
                            value: masterProduct,
                            isDark: isDark,
                            items: [
                              const DropdownMenuItem(value: 'all', child: Text('All Products')),
                              ...uniqueProducts.map((p) {
                                return DropdownMenuItem(
                                  value: p,
                                  child: Text(p),
                                );
                              }),
                            ],
                            onChanged: (val) {
                              if (val != null) ref.read(dcMasterProductFilterProvider.notifier).state = val;
                            },
                          ),
                          const SizedBox(width: 8),

                          // 6. Client Filter Dropdown
                          _buildFilterDropdown(
                            label: 'Client',
                            icon: Icons.business_rounded,
                            value: masterClient,
                            isDark: isDark,
                            items: [
                              const DropdownMenuItem(value: 'all', child: Text('All Clients')),
                              ...uniqueClients.map((c) {
                                return DropdownMenuItem(
                                  value: c,
                                  child: Text(c),
                                );
                              }),
                            ],
                            onChanged: (val) {
                              if (val != null) ref.read(dcMasterClientFilterProvider.notifier).state = val;
                            },
                          ),

                          // 7. Reset Filters Button
                          if (hasActiveFilters) ...[
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: () {
                                _masterSearchController.clear();
                                ref.read(dcMasterSearchProvider.notifier).state = '';
                                ref.read(dcMasterStatusFilterProvider.notifier).state = 'all';
                                ref.read(dcMasterRemittanceFilterProvider.notifier).state = 'all';
                                ref.read(dcMasterRiderFilterProvider.notifier).state = 'all';
                                ref.read(dcMasterProductFilterProvider.notifier).state = 'all';
                                ref.read(dcMasterClientFilterProvider.notifier).state = 'all';
                                ref.read(dcOrdersDateFilterProvider.notifier).state = 'all_time';
                                ref.read(dcOrdersCustomDateRangeProvider.notifier).state = null;
                                ref.read(dcOrdersSingleDateProvider.notifier).state = null;
                              },
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                height: 40,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.4)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.restart_alt_rounded, size: 16, color: Color(0xFFEF4444)),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Reset Filters',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFFEF4444),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 4. Orders Directory View (Table or Grid)
          if (ordersState.isLoading)
            Column(
              children: List.generate(4, (index) => const OrderCardSkeleton()),
            )
          else if (filtered.isEmpty)
            _buildEmptyState(
              isDark,
              icon: Icons.search_off_rounded,
              title: 'No Orders Match Your Filters',
              subtitle: 'Try adjusting your search query, status, rider, product, or date filters to find matching shipments.',
            )
          else if (viewMode == 'table')
            _buildMasterOrdersTable(context, isDark, filtered, dcState, ordersState)
          else
            _buildMasterOrdersGrid(context, isDark, filtered, dcState, ordersState),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown({
    required String label,
    required IconData icon,
    required String value,
    required bool isDark,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
  }) {
    // Ensure value exists in items
    final bool valueExists = items.any((item) => item.value == value);
    final safeValue = valueExists ? value : 'all';

    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: safeValue != 'all' ? const Color(0xFF2563EB) : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: safeValue != 'all' ? const Color(0xFF2563EB) : const Color(0xFF64748B)),
          const SizedBox(width: 6),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: safeValue,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: safeValue != 'all' ? FontWeight.bold : FontWeight.w500,
                color: safeValue != 'all' ? const Color(0xFF2563EB) : (isDark ? Colors.white : const Color(0xFF0F172A)),
              ),
              dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              items: items,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMasterOrdersTable(
    BuildContext context,
    bool isDark,
    List<OrderEntity> orders,
    DCConsoleState dcState,
    OrdersState ordersState,
  ) {
    final totalCount = orders.length;
    final totalPages = (totalCount / _masterPageSize).ceil().clamp(1, 9999);
    final currentPage = _masterCurrentPage.clamp(0, totalPages - 1);
    final startIndex = currentPage * _masterPageSize;
    final endIndex = (startIndex + _masterPageSize).clamp(0, totalCount);
    final pagedOrders = totalCount == 0 ? <OrderEntity>[] : orders.sublist(startIndex, endIndex);

    return Container(
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                showCheckboxColumn: false,
                headingRowColor: WidgetStateProperty.all(isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
                headingRowHeight: 46,
                dataRowMaxHeight: 64,
                columnSpacing: 18,
                columns: [
                  const DataColumn(label: Text('Order # & Date', style: TextStyle(fontWeight: FontWeight.bold))),
                  const DataColumn(label: Text('Customer & Phone', style: TextStyle(fontWeight: FontWeight.bold))),
                  const DataColumn(label: Text('Destination', style: TextStyle(fontWeight: FontWeight.bold))),
                  const DataColumn(label: Text('Product & Qty', style: TextStyle(fontWeight: FontWeight.bold))),
                  const DataColumn(label: Text('Amount & Payment', style: TextStyle(fontWeight: FontWeight.bold))),
                  const DataColumn(label: Text('Client', style: TextStyle(fontWeight: FontWeight.bold))),
                  const DataColumn(label: Text('Assigned Rider', style: TextStyle(fontWeight: FontWeight.bold))),
                  const DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                  const DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                ],
                rows: pagedOrders.map((order) {
                  final isUnassigned = order.deliveryAgentId == null || order.deliveryAgentId!.isEmpty;
                  final isDelivered = order.status == 'delivered';
                  final isFailed = order.status == 'cancelled' || order.status == 'failed' || order.status == 'call_back';
                  final isReturned = order.status == 'returned';
                  final isPrepaid = order.paymentType == 'prepaid' || order.isDirectTransfer;

                  return DataRow(
                    onSelectChanged: (_) {
                      showDialog(
                        context: context,
                        builder: (ctx) => DCOrderDetailModal(order: order),
                      );
                    },
                    mouseCursor: WidgetStateProperty.all(SystemMouseCursors.click),
                    color: WidgetStateProperty.resolveWith<Color?>((states) {
                      if (states.contains(WidgetState.hovered)) {
                        return isDark ? const Color(0xFF334155).withValues(alpha: 0.5) : const Color(0xFFF1F5F9);
                      }
                      return null;
                    }),
                    cells: [
                      // 1. Order # & Date
                      DataCell(
                        InkWell(
                          onTap: () => showDialog(context: context, builder: (ctx) => DCOrderDetailModal(order: order)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '#${order.orderNumber}',
                                style: GoogleFonts.jetBrainsMono(fontSize: 12.5, fontWeight: FontWeight.bold, color: const Color(0xFF2563EB)),
                              ),
                              Text(
                                DateTimeFormatter.formatRelativeTime(order.createdAt),
                                style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF94A3B8)),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // 2. Customer & Phone
                      DataCell(
                        InkWell(
                          onTap: () => showDialog(context: context, builder: (ctx) => DCOrderDetailModal(order: order)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                order.customerName,
                                style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                order.customerPhone,
                                style: GoogleFonts.jetBrainsMono(fontSize: 11, color: const Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // 3. Destination
                      DataCell(
                        InkWell(
                          onTap: () => showDialog(context: context, builder: (ctx) => DCOrderDetailModal(order: order)),
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 180),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  order.deliveryAddress,
                                  style: GoogleFonts.inter(fontSize: 11.5),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  '${order.deliveryCity}, ${order.deliveryState}',
                                  style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF64748B)),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // 4. Product & Qty
                      DataCell(
                        InkWell(
                          onTap: () => showDialog(context: context, builder: (ctx) => DCOrderDetailModal(order: order)),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '${order.quantity}x',
                                  style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF8B5CF6)),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(order.productName, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ),
                      ),

                      // 5. Amount & Payment
                      DataCell(
                        InkWell(
                          onTap: () => showDialog(context: context, builder: (ctx) => DCOrderDetailModal(order: order)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                CurrencyFormatter.formatNaira(order.totalAmount),
                                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF16A34A)),
                              ),
                              Text(
                                isPrepaid ? '⚡ Prepaid' : '💵 Pay on Del',
                                style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // 6. Client
                      DataCell(
                        InkWell(
                          onTap: () => showDialog(context: context, builder: (ctx) => DCOrderDetailModal(order: order)),
                          child: Text(order.clientName.isNotEmpty ? order.clientName : 'Novacare', style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B))),
                        ),
                      ),

                      // 7. Assigned Rider
                      DataCell(
                        InkWell(
                          onTap: () => showDialog(context: context, builder: (ctx) => DCOrderDetailModal(order: order)),
                          child: Text(
                            isUnassigned ? 'Unassigned' : (order.deliveryAgentName ?? order.deliveryAgentCode ?? 'Assigned'),
                            style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w500, color: isUnassigned ? const Color(0xFFEA580C) : const Color(0xFF2563EB)),
                          ),
                        ),
                      ),

                      // 8. Status
                      DataCell(
                        InkWell(
                          onTap: () => showDialog(context: context, builder: (ctx) => DCOrderDetailModal(order: order)),
                          child: _buildOrderStatusBadge(order),
                        ),
                      ),

                      // 9. Actions
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isUnassigned && !isDelivered && !isFailed && !isReturned) ...[
                              ElevatedButton.icon(
                                onPressed: () {
                                  _showAssignRiderModal(context, isDark, order, dcState, ordersState);
                                },
                                icon: const Icon(Icons.send_rounded, size: 13, color: Colors.white),
                                label: const Text('Assign Rider', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFF37021),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                ),
                              ),
                              const SizedBox(width: 6),
                            ],
                            IconButton(
                              icon: const Icon(Icons.visibility_outlined, size: 16, color: Color(0xFF2563EB)),
                              tooltip: 'View Order Details & Audit Trail',
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (ctx) => DCOrderDetailModal(order: order),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),

            // Pagination Controls Toolbar (Fully Responsive without overflow)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                border: Border(top: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
              ),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: [
                  Text(
                    totalCount == 0
                        ? 'No orders found'
                        : 'Showing ${startIndex + 1} to $endIndex of $totalCount orders',
                    style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B), fontWeight: FontWeight.w500),
                  ),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Per page:', style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B))),
                        const SizedBox(width: 6),
                        DropdownButton<int>(
                          value: _masterPageSize,
                          isDense: true,
                          underline: const SizedBox(),
                          items: const [
                            DropdownMenuItem(value: 25, child: Text('25')),
                            DropdownMenuItem(value: 50, child: Text('50')),
                            DropdownMenuItem(value: 100, child: Text('100')),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _masterPageSize = val;
                                _masterCurrentPage = 0;
                              });
                            }
                          },
                        ),
                        const SizedBox(width: 14),
                        IconButton(
                          icon: const Icon(Icons.chevron_left_rounded, size: 20),
                          onPressed: currentPage > 0
                              ? () => setState(() => _masterCurrentPage = currentPage - 1)
                              : null,
                        ),
                        Text(
                          'Page ${currentPage + 1} of $totalPages',
                          style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right_rounded, size: 20),
                          onPressed: currentPage < totalPages - 1
                              ? () => setState(() => _masterCurrentPage = currentPage + 1)
                              : null,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMasterOrdersGrid(
    BuildContext context,
    bool isDark,
    List<OrderEntity> orders,
    DCConsoleState dcState,
    OrdersState ordersState,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth < 650 ? 1 : (constraints.maxWidth < 1100 ? 2 : 3);
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: 1.6,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
          ),
          itemCount: orders.length,
          itemBuilder: (ctx, idx) {
            final order = orders[idx];
            final isUnassigned = order.deliveryAgentId == null || order.deliveryAgentId!.isEmpty;
            final isDelivered = order.status == 'delivered';
            final isFailed = order.status == 'cancelled' || order.status == 'failed' || order.status == 'call_back';

            return InkWell(
              onTap: () {
                showDialog(
                  context: context,
                  builder: (ctx) => DCOrderDetailModal(order: order),
                );
              },
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('#${order.orderNumber}', style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF2563EB))),
                        _buildOrderStatusBadge(order),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(order.customerName, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold)),
                        Text('${order.customerPhone} • ${order.deliveryAddress}, ${order.deliveryCity}', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)), maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Text('${order.quantity}x ${order.productName} • ${CurrencyFormatter.formatNaira(order.totalAmount)}', style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: const Color(0xFF16A34A))),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isUnassigned ? 'Unassigned' : '🚴 ${order.deliveryAgentName ?? "Rider"}',
                          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: isUnassigned ? const Color(0xFFF37021) : const Color(0xFF2563EB)),
                        ),
                        Row(
                          children: [
                            if (isUnassigned && !isDelivered && !isFailed)
                              ElevatedButton(
                                onPressed: () => _showAssignRiderModal(context, isDark, order, dcState, ordersState),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFF37021),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                ),
                                child: const Text('Assign', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                              ),
                            const SizedBox(width: 6),
                            OutlinedButton(
                              onPressed: () => showDialog(context: context, builder: (ctx) => DCOrderDetailModal(order: order)),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                              ),
                              child: const Text('Details', style: TextStyle(fontSize: 11)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildOrderStatusBadge(OrderEntity order) {
    final status = order.status.toLowerCase();
    final isUnassigned = order.deliveryAgentId == null || order.deliveryAgentId!.isEmpty;

    if (status == 'delivered') {
      final isCashAwaitingRemittance = order.isUnremitted && !order.isDirectTransfer;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
            decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(6)),
            child: Text('DELIVERED ✓', style: GoogleFonts.jetBrainsMono(fontSize: 9.5, fontWeight: FontWeight.bold, color: const Color(0xFF16A34A))),
          ),
          if (isCashAwaitingRemittance) ...[
            const SizedBox(height: 3),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Text(
                'AWAITING REMITTANCE',
                style: GoogleFonts.jetBrainsMono(fontSize: 8, fontWeight: FontWeight.bold, color: const Color(0xFFB45309)),
              ),
            ),
          ],
        ],
      );
    }
    if (status == 'returned') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
        decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(6)),
        child: Text('RETURNED', style: GoogleFonts.jetBrainsMono(fontSize: 9.5, fontWeight: FontWeight.bold, color: const Color(0xFFB45309))),
      );
    }
    if (status == 'failed' || status == 'cancelled' || status == 'call_back') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
        decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(6)),
        child: Text('FAILED / CB', style: GoogleFonts.jetBrainsMono(fontSize: 9.5, fontWeight: FontWeight.bold, color: const Color(0xFFDC2626))),
      );
    }
    if (isUnassigned) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
        decoration: BoxDecoration(color: const Color(0xFFFFF7ED), borderRadius: BorderRadius.circular(6), border: Border.all(color: const Color(0xFFFFEDD5))),
        child: Text('UNASSIGNED', style: GoogleFonts.jetBrainsMono(fontSize: 9.5, fontWeight: FontWeight.bold, color: const Color(0xFFEA580C))),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(6)),
      child: Text('IN TRANSIT', style: GoogleFonts.jetBrainsMono(fontSize: 9.5, fontWeight: FontWeight.bold, color: const Color(0xFF2563EB))),
    );
  }

  Widget _buildEmptyState(
    bool isDark, {
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 36, color: const Color(0xFF2563EB)),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }


  void _showAssignRiderModal(
    BuildContext context,
    bool isDark,
    OrderEntity order,
    DCConsoleState dcState,
    OrdersState ordersState,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => DCAssignOrderModal(order: order),
    );
  }

  void _autoAssignPool(List<OrderEntity> unassigned, DCConsoleState dcState, OrdersState ordersState) async {
    if (dcState.drivers.isEmpty) return;

    int assignedCount = 0;
    for (int i = 0; i < unassigned.length; i++) {
      final order = unassigned[i];

      // 1. Try server-side proximity auto-dispatch
      final proximityResult = await ref.read(ordersProvider.notifier).autoDispatchToNearestRider(order.id);
      if (proximityResult['success'] == true && proximityResult['riderId'] != null) {
        assignedCount++;
        continue;
      }

      // 2. Fallback: Pick driver with available vehicle stock and lowest current workload
      final stockNotifier = ref.read(stockProvider.notifier);
      final stockState = ref.read(stockProvider);

      final eligibleDrivers = dcState.drivers.where((d) {
        final avail = stockNotifier.getRiderAvailableStock(
          riderId: d.id,
          riderCode: d.driverCode,
          productName: order.productName,
          activeOrders: ordersState.orders,
        );
        final totalCustody = stockState.getAllocationsForRider(d.id, d.driverCode).where((a) {
          final pA = a.productName.toLowerCase();
          final oP = order.productName.toLowerCase();
          return (oP.isNotEmpty && (pA.contains(oP) || oP.contains(pA))) ||
              (a.sku.isNotEmpty && oP.contains(a.sku.toLowerCase()));
        }).fold(0, (sum, a) => sum + a.inCustodyUnits);

        return order.isClientPackage || (totalCustody > 0 && avail >= order.quantity);
      }).toList();

      if (eligibleDrivers.isEmpty) {
        // No driver has sufficient stock for this order
        continue;
      }

      eligibleDrivers.sort((a, b) {
        final aCount = ordersState.orders.where((o) => o.deliveryAgentId == a.id || o.deliveryAgentCode == a.driverCode).length;
        final bCount = ordersState.orders.where((o) => o.deliveryAgentId == b.id || o.deliveryAgentCode == b.driverCode).length;
        return aCount.compareTo(bCount);
      });

      final targetDriver = eligibleDrivers.first;
      final assigned = await ref.read(ordersProvider.notifier).assignOrderToRider(
        orderId: order.id,
        riderId: targetDriver.id,
        riderName: targetDriver.name,
        riderCode: targetDriver.driverCode,
      );
      if (assigned) {
        assignedCount++;
      }
    }

    if (mounted) {
      final unassignedRemaining = unassigned.length - assignedCount;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            unassignedRemaining > 0
                ? '⚡ Auto-dispatched $assignedCount orders. $unassignedRemaining order(s) skipped due to insufficient vehicle stock.'
                : '⚡ Auto-dispatched all $assignedCount orders using proximity GIS and stock availability.',
          ),
          backgroundColor: assignedCount > 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444),
        ),
      );
    }
  }

  // ==========================================
  // DELIVERED ORDERS WIDGET HELPERS & MODALS
  // ==========================================

  Widget _buildDeliveredKpiCard(
    bool isDark, {
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required double width,
    VoidCallback? onTap,
  }) {
    final cardContent = Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, size: 14, color: iconColor),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 13.5,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 1),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              fontSize: 9.5,
              color: const Color(0xFF94A3B8),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: cardContent,
      );
    }
    return cardContent;
  }
}

