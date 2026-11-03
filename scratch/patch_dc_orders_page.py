with open('lib/features/dc_console/presentation/pages/dc_orders_page.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Update callers of _buildAllOrdersView around line 219
old_call = """            final mainView = _buildAllOrdersView(
              isDark,
              dateFilteredOrders,
              dcState,
              ordersState,
              unassignedOrders.length,
              inTransitOrders.length,
              deliveredOrders.length,
              failedOrders.length,
            );"""

new_call = """            final readyOrders = dateFilteredOrders.where((o) => o.status == 'ready').toList();
            final rescheduledOrders = dateFilteredOrders.where((o) => o.status == 'rescheduled').toList();
            final dispatchAssignedOrders = dateFilteredOrders.where((o) => o.status == 'dispatch_assigned').toList();

            final mainView = _buildAllOrdersView(
              isDark,
              dateFilteredOrders,
              dcState,
              ordersState,
              unassignedOrders.length,
              inTransitOrders.length,
              deliveredOrders.length,
              failedOrders.length,
              readyOrders.length,
              rescheduledOrders.length,
              dispatchAssignedOrders.length,
            );"""

assert old_call in content, 'old_call not found'
content = content.replace(old_call, new_call, 1)

# 2. Update _buildAllOrdersView signature
old_sig = """  Widget _buildAllOrdersView(
    bool isDark,
    List<OrderEntity> allOrders,
    DCConsoleState dcState,
    OrdersState ordersState,
    int unassignedCount,
    int inTransitCount,
    int deliveredCount,
    int failedCount,
  ) {"""

new_sig = """  Widget _buildAllOrdersView(
    bool isDark,
    List<OrderEntity> allOrders,
    DCConsoleState dcState,
    OrdersState ordersState,
    int unassignedCount,
    int inTransitCount,
    int deliveredCount,
    int failedCount,
    int readyCount,
    int rescheduledCount,
    int dispatchAssignedCount,
  ) {"""

assert old_sig in content, 'old_sig not found'
content = content.replace(old_sig, new_sig, 1)

# 3. Update filter handling in _buildAllOrdersView
old_filter = """        } else if (masterStatus == 'failed') {
          if (o.status != 'cancelled' && o.status != 'failed' && o.status != 'call_back') return false;
        } else if (masterStatus == 'returned') {"""

new_filter = """        } else if (masterStatus == 'ready') {
          if (o.status != 'ready') return false;
        } else if (masterStatus == 'dispatch_assigned') {
          if (o.status != 'dispatch_assigned') return false;
        } else if (masterStatus == 'rescheduled') {
          if (o.status != 'rescheduled') return false;
        } else if (masterStatus == 'failed') {
          if (o.status != 'cancelled' && o.status != 'failed' && o.status != 'call_back') return false;
        } else if (masterStatus == 'returned') {"""

assert old_filter in content, 'old_filter not found'
content = content.replace(old_filter, new_filter, 1)

# 4. Update _buildQuickStatusTabStrip call in _buildAllOrdersView
old_tab_call = """          _buildQuickStatusTabStrip(
            isDark: isDark,
            currentStatus: masterStatus,
            totalCount: allOrders.length,
            completedCount: deliveredCount,
            inTransitCount: inTransitCount,
            unassignedCount: unassignedCount,
            failedCount: failedCount,
          ),"""

new_tab_call = """          _buildQuickStatusTabStrip(
            isDark: isDark,
            currentStatus: masterStatus,
            totalCount: allOrders.length,
            completedCount: deliveredCount,
            inTransitCount: inTransitCount,
            unassignedCount: unassignedCount,
            failedCount: failedCount,
            readyCount: readyCount,
            rescheduledCount: rescheduledCount,
            dispatchAssignedCount: dispatchAssignedCount,
          ),"""

assert old_tab_call in content, 'old_tab_call not found'
content = content.replace(old_tab_call, new_tab_call, 1)

# 5. Update _buildQuickStatusTabStrip definition
old_strip_def = """  Widget _buildQuickStatusTabStrip({
    required bool isDark,
    required String currentStatus,
    required int totalCount,
    required int completedCount,
    required int inTransitCount,
    required int unassignedCount,
    required int failedCount,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            _buildStatusTabPill(
              label: 'Most Recent (All)',
              count: totalCount,
              icon: Icons.history_rounded,
              color: const Color(0xFF2563EB),
              isSelected: currentStatus == 'all',
              isDark: isDark,
              onTap: () => ref.read(dcMasterStatusFilterProvider.notifier).state = 'all',
            ),
            const SizedBox(width: 8),
            _buildStatusTabPill(
              label: 'Completed ✓',
              count: completedCount,
              icon: Icons.check_circle_rounded,
              color: const Color(0xFF10B981),
              isSelected: currentStatus == 'delivered',
              isDark: isDark,
              onTap: () => ref.read(dcMasterStatusFilterProvider.notifier).state = 'delivered',
            ),
            const SizedBox(width: 8),
            _buildStatusTabPill(
              label: 'In Transit',
              count: inTransitCount,
              icon: Icons.local_shipping_rounded,
              color: const Color(0xFF0284C7),
              isSelected: currentStatus == 'in_transit',
              isDark: isDark,
              onTap: () => ref.read(dcMasterStatusFilterProvider.notifier).state = 'in_transit',
            ),
            const SizedBox(width: 8),
            _buildStatusTabPill(
              label: 'Unassigned',
              count: unassignedCount,
              icon: Icons.outbox_rounded,
              color: const Color(0xFFF37021),
              isSelected: currentStatus == 'unassigned',
              isDark: isDark,
              onTap: () => ref.read(dcMasterStatusFilterProvider.notifier).state = 'unassigned',
            ),
            const SizedBox(width: 8),
            _buildStatusTabPill(
              label: 'Issues',
              count: failedCount,
              icon: Icons.warning_amber_rounded,
              color: const Color(0xFFDC2626),
              isSelected: currentStatus == 'failed',
              isDark: isDark,
              onTap: () => ref.read(dcMasterStatusFilterProvider.notifier).state = 'failed',
            ),
          ],
        ),
      ),
    );
  }"""

new_strip_def = """  Widget _buildQuickStatusTabStrip({
    required bool isDark,
    required String currentStatus,
    required int totalCount,
    required int completedCount,
    required int inTransitCount,
    required int unassignedCount,
    required int failedCount,
    required int readyCount,
    required int rescheduledCount,
    required int dispatchAssignedCount,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            _buildStatusTabPill(
              label: 'Most Recent (All)',
              count: totalCount,
              icon: Icons.history_rounded,
              color: const Color(0xFF2563EB),
              isSelected: currentStatus == 'all',
              isDark: isDark,
              onTap: () => ref.read(dcMasterStatusFilterProvider.notifier).state = 'all',
            ),
            const SizedBox(width: 8),
            _buildStatusTabPill(
              label: 'Ready 🚀',
              count: readyCount,
              icon: Icons.outbox_rounded,
              color: const Color(0xFF0D9488),
              isSelected: currentStatus == 'ready',
              isDark: isDark,
              onTap: () => ref.read(dcMasterStatusFilterProvider.notifier).state = 'ready',
            ),
            const SizedBox(width: 8),
            _buildStatusTabPill(
              label: 'Rescheduled 📅',
              count: rescheduledCount,
              icon: Icons.calendar_month_rounded,
              color: const Color(0xFFEA580C),
              isSelected: currentStatus == 'rescheduled',
              isDark: isDark,
              onTap: () => ref.read(dcMasterStatusFilterProvider.notifier).state = 'rescheduled',
            ),
            const SizedBox(width: 8),
            _buildStatusTabPill(
              label: 'Dispatch Assigned',
              count: dispatchAssignedCount,
              icon: Icons.two_wheeler_rounded,
              color: const Color(0xFF2563EB),
              isSelected: currentStatus == 'dispatch_assigned',
              isDark: isDark,
              onTap: () => ref.read(dcMasterStatusFilterProvider.notifier).state = 'dispatch_assigned',
            ),
            const SizedBox(width: 8),
            _buildStatusTabPill(
              label: 'In Transit',
              count: inTransitCount,
              icon: Icons.local_shipping_rounded,
              color: const Color(0xFF0284C7),
              isSelected: currentStatus == 'in_transit',
              isDark: isDark,
              onTap: () => ref.read(dcMasterStatusFilterProvider.notifier).state = 'in_transit',
            ),
            const SizedBox(width: 8),
            _buildStatusTabPill(
              label: 'Completed ✓',
              count: completedCount,
              icon: Icons.check_circle_rounded,
              color: const Color(0xFF10B981),
              isSelected: currentStatus == 'delivered',
              isDark: isDark,
              onTap: () => ref.read(dcMasterStatusFilterProvider.notifier).state = 'delivered',
            ),
            const SizedBox(width: 8),
            _buildStatusTabPill(
              label: 'Issues',
              count: failedCount,
              icon: Icons.warning_amber_rounded,
              color: const Color(0xFFDC2626),
              isSelected: currentStatus == 'failed',
              isDark: isDark,
              onTap: () => ref.read(dcMasterStatusFilterProvider.notifier).state = 'failed',
            ),
          ],
        ),
      ),
    );
  }"""

assert old_strip_def in content, 'old_strip_def not found'
content = content.replace(old_strip_def, new_strip_def, 1)

# 6. Update _buildOrderStatusBadge in dc_orders_page.dart
badge_target = """  Widget _buildOrderStatusBadge(OrderEntity order) {
    final status = order.status.toLowerCase();
    final isUnassigned = order.deliveryAgentId == null || order.deliveryAgentId!.isEmpty;"""

badge_replacement = """  Widget _buildOrderStatusBadge(OrderEntity order) {
    final status = order.status.toLowerCase();
    final isUnassigned = order.deliveryAgentId == null || order.deliveryAgentId!.isEmpty;

    if (status == 'ready') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
        decoration: BoxDecoration(
          color: const Color(0xFFCCFBF1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFF5EEAD4)),
        ),
        child: Text('READY', style: GoogleFonts.jetBrainsMono(fontSize: 9.5, fontWeight: FontWeight.bold, color: const Color(0xFF0F766E))),
      );
    }
    if (status == 'dispatch_assigned') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
        decoration: BoxDecoration(
          color: const Color(0xFFDBEAFE),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFF93C5FD)),
        ),
        child: Text('DISPATCH ASSIGNED', style: GoogleFonts.jetBrainsMono(fontSize: 9.5, fontWeight: FontWeight.bold, color: const Color(0xFF1D4ED8))),
      );
    }
    if (status == 'order_accepted') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
        decoration: BoxDecoration(
          color: const Color(0xFFD1FAE5),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFF6EE7B7)),
        ),
        child: Text('ORDER ACCEPTED', style: GoogleFonts.jetBrainsMono(fontSize: 9.5, fontWeight: FontWeight.bold, color: const Color(0xFF047857))),
      );
    }
    if (status == 'rescheduled') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
        decoration: BoxDecoration(
          color: const Color(0xFFFFEDD5),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFFDBA74)),
        ),
        child: Text('RESCHEDULED', style: GoogleFonts.jetBrainsMono(fontSize: 9.5, fontWeight: FontWeight.bold, color: const Color(0xFFC2410C))),
      );
    }
    if (status == 'not_picking') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF3C7),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFFDE68A)),
        ),
        child: Text('NOT PICKING', style: GoogleFonts.jetBrainsMono(fontSize: 9.5, fontWeight: FontWeight.bold, color: const Color(0xFFB45309))),
      );
    }"""

assert badge_target in content, 'badge_target not found'
content = content.replace(badge_target, badge_replacement, 1)

with open('lib/features/dc_console/presentation/pages/dc_orders_page.dart', 'w', encoding='utf-8') as f:
    f.write(content)

print('dc_orders_page.dart updated successfully!')

