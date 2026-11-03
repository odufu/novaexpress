with open('lib/features/client_portal/presentation/pages/closer_mobile_portal_page.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Update status filter logic
old_filter_logic = """        if (statusFilter == 'new_leads' && !(o.status.toLowerCase() == 'new' || o.status.toLowerCase() == 'unconfirmed' || o.status.toLowerCase() == 'contacting')) return false;
        if (statusFilter == 'in_transit' && !o.isAssignedInTransit) return false;
        if (statusFilter == 'delivered' && !o.isDelivered) return false;
        if (statusFilter == 'pending' && (o.isDelivered || o.isFailed || o.isAssignedInTransit || o.status.toLowerCase() == 'new')) return false;
        if (statusFilter == 'failed' && !o.isFailed) return false;"""

new_filter_logic = """        if (statusFilter == 'assigned' && o.status.toLowerCase() != 'assigned') return false;
        if (statusFilter == 'ready' && o.status.toLowerCase() != 'ready') return false;
        if (statusFilter == 'rescheduled' && o.status.toLowerCase() != 'rescheduled') return false;
        if (statusFilter == 'new_leads' && !(o.status.toLowerCase() == 'new' || o.status.toLowerCase() == 'unconfirmed' || o.status.toLowerCase() == 'contacting' || o.status.toLowerCase() == 'assigned')) return false;
        if (statusFilter == 'in_transit' && !o.isAssignedInTransit) return false;
        if (statusFilter == 'delivered' && !o.isDelivered) return false;
        if (statusFilter == 'pending' && (o.isDelivered || o.isFailed || o.isAssignedInTransit || o.status.toLowerCase() == 'new')) return false;
        if (statusFilter == 'failed' && !o.isFailed && !o.isCallBack) return false;"""

assert old_filter_logic in content, 'old_filter_logic not found'
content = content.replace(old_filter_logic, new_filter_logic, 1)

# 2. Update filter chips
idx_start = content.find("_buildFilterChip('all', 'All (${baseOrders.length})'")
idx_end = content.find("_buildFilterChip('failed', 'Failed/Callback', statusFilter, isDark),", idx_start)
idx_end += len("_buildFilterChip('failed', 'Failed/Callback', statusFilter, isDark),")

new_chips = """_buildFilterChip('all', 'All (${baseOrders.length})', statusFilter, isDark),
                      const SizedBox(width: 8),
                      _buildFilterChip('assigned', 'Assigned (${baseOrders.where((o) => o.status.toLowerCase() == 'assigned').length})', statusFilter, isDark),
                      const SizedBox(width: 8),
                      _buildFilterChip('ready', 'Ready (${baseOrders.where((o) => o.status.toLowerCase() == 'ready').length})', statusFilter, isDark),
                      const SizedBox(width: 8),
                      _buildFilterChip('rescheduled', 'Rescheduled (${baseOrders.where((o) => o.status.toLowerCase() == 'rescheduled').length})', statusFilter, isDark),
                      const SizedBox(width: 8),
                      _buildFilterChip('in_transit', 'In Transit (${baseOrders.where((o) => o.isAssignedInTransit).length})', statusFilter, isDark),
                      const SizedBox(width: 8),
                      _buildFilterChip('delivered', 'Delivered (${baseOrders.where((o) => o.isDelivered).length})', statusFilter, isDark),
                      const SizedBox(width: 8),
                      _buildFilterChip('failed', 'Issues/Callback (${baseOrders.where((o) => o.isFailed || o.isCallBack).length})', statusFilter, isDark),"""

content = content[:idx_start] + new_chips + content[idx_end:]

# 3. Update status labels in _buildOrderCard
old_labels = """    final isNewLead = order.status.toLowerCase() == 'new' ||
        order.status.toLowerCase() == 'unconfirmed' ||
        order.status.toLowerCase() == 'contacting';

    if (order.isDelivered) {
      statusColor = const Color(0xFF10B981);
      statusLabel = 'DELIVERED';
    } else if (order.isAssignedInTransit) {
      statusColor = const Color(0xFF3B82F6);
      statusLabel = 'IN TRANSIT';
    } else if (order.isFailed) {
      statusColor = const Color(0xFFEF4444);
      statusLabel = 'FAILED / RETURN';
    } else if (isNewLead) {
      statusColor = const Color(0xFFF97316);
      statusLabel = 'NEW LEAD (UNCONFIRMED)';
    } else {
      statusColor = const Color(0xFFF59E0B);
      statusLabel = 'PENDING DISPATCH';
    }"""

new_labels = """    final isNewLead = order.status.toLowerCase() == 'new' ||
        order.status.toLowerCase() == 'unconfirmed' ||
        order.status.toLowerCase() == 'contacting' ||
        order.status.toLowerCase() == 'assigned';

    if (order.isDelivered) {
      statusColor = const Color(0xFF10B981);
      statusLabel = 'DELIVERED';
    } else if (order.isAssignedInTransit) {
      statusColor = const Color(0xFF3B82F6);
      statusLabel = 'IN TRANSIT';
    } else if (order.isRescheduled) {
      statusColor = const Color(0xFFEA580C);
      statusLabel = 'RESCHEDULED';
    } else if (order.isReady) {
      statusColor = const Color(0xFF0D9488);
      statusLabel = 'READY (AT DC)';
    } else if (order.isAssignedToCloser) {
      statusColor = const Color(0xFF8B5CF6);
      statusLabel = 'ASSIGNED';
    } else if (order.isFailed) {
      statusColor = const Color(0xFFEF4444);
      statusLabel = 'FAILED / RETURN';
    } else if (isNewLead) {
      statusColor = const Color(0xFFF97316);
      statusLabel = 'NEW LEAD';
    } else {
      statusColor = const Color(0xFFF59E0B);
      statusLabel = 'PENDING DISPATCH';
    }"""

assert old_labels in content, 'old_labels not found'
content = content.replace(old_labels, new_labels, 1)

# 4. Update action buttons in _buildOrderCard
old_action_block = """                  // 2. Confirm & Auto-Dispatch Button
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => ClientConfirmOrderModal.show(context, order),
                      icon: const Icon(Icons.verified_rounded, size: 14, color: Colors.white),
                      label: Text(
                        'Confirm & Dispatch',
                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),"""

new_action_block = """                  // 2. Confirm Ready Button
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => ClientConfirmOrderModal.show(context, order),
                      icon: const Icon(Icons.verified_rounded, size: 14, color: Colors.white),
                      label: Text(
                        'Confirm Ready',
                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),

                  // 3. Reschedule Action Button
                  IconButton(
                    tooltip: 'Reschedule Order',
                    onPressed: () {
                      RescheduleCallbackModal.show(
                        context: context,
                        orderId: order.id,
                        customerName: order.customerName,
                        onRescheduleConfirmed: (dt, note) async {
                          final updated = order.copyWith(
                            status: 'rescheduled',
                            rescheduledDeliveryDate: dt,
                            deliveryNotes: '${order.deliveryNotes ?? ""}\\n[RESCHEDULED] $note',
                          );
                          await ref.read(ordersProvider.notifier).updateOrder(updated);
                        },
                      );
                    },
                    icon: const Icon(Icons.event_repeat_rounded, size: 16, color: Color(0xFFEA580C)),
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFFEA580C).withValues(alpha: 0.12),
                      padding: const EdgeInsets.all(9),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(width: 6),

                  // 4. Not Picking Action Button
                  IconButton(
                    tooltip: 'Customer Not Picking',
                    onPressed: () async {
                      await ref.read(ordersProvider.notifier).updateOrderStatus(
                        order.id,
                        'not_picking',
                        notes: 'Closer called customer - not picking calls.',
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          backgroundColor: Color(0xFFD97706),
                          content: Text('Status marked: Customer Not Picking! 📵'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.phone_missed_rounded, size: 16, color: Color(0xFFD97706)),
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFFD97706).withValues(alpha: 0.12),
                      padding: const EdgeInsets.all(9),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(width: 6),"""

assert old_action_block in content, 'old_action_block not found'
content = content.replace(old_action_block, new_action_block, 1)

with open('lib/features/client_portal/presentation/pages/closer_mobile_portal_page.dart', 'w', encoding='utf-8') as f:
    f.write(content)

print('closer_mobile_portal_page.dart updated successfully via scratch script!')

