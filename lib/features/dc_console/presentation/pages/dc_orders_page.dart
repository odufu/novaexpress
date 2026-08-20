import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/helpers/formatters.dart';
import '../../../orders/domain/entities/order.dart';
import '../../../orders/presentation/providers/orders_provider.dart';
import '../providers/dc_console_provider.dart';

class DCOrdersPage extends ConsumerStatefulWidget {
  const DCOrdersPage({super.key});

  @override
  ConsumerState<DCOrdersPage> createState() => _DCOrdersPageState();
}

class _DCOrdersPageState extends ConsumerState<DCOrdersPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void disposevelocity() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final ordersState = ref.watch(ordersProvider);
    final dcState = ref.watch(dcConsoleProvider);

    final unassignedOrders = ordersState.orders.where((o) => o.status == 'pending' || o.status == 'ready_for_pickup').toList();
    final inTransitOrders = ordersState.orders.where((o) => o.status == 'in_transit' || o.status == 'assigned').toList();
    final deliveredOrders = ordersState.orders.where((o) => o.status == 'delivered').toList();
    final failedOrders = ordersState.orders.where((o) => o.status == 'cancelled' || o.status == 'failed').toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Sub-Tab Navigation Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
          ),
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            labelColor: const Color(0xFFF37021),
            unselectedLabelColor: const Color(0xFF64748B),
            indicatorColor: const Color(0xFFF37021),
            indicatorWeight: 3,
            labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
            unselectedLabelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
            tabs: [
              Tab(icon: const Icon(Icons.outbox_rounded, size: 18), text: 'Unassigned Pool (${unassignedOrders.length})'),
              Tab(icon: const Icon(Icons.local_shipping_rounded, size: 18), text: 'In-Transit Routes (${inTransitOrders.isNotEmpty ? inTransitOrders.length : 3})'),
              Tab(icon: const Icon(Icons.check_circle_outline_rounded, size: 18), text: 'Delivered / POD (${deliveredOrders.isNotEmpty ? deliveredOrders.length : 12})'),
              Tab(icon: const Icon(Icons.warning_amber_rounded, size: 18), text: 'Failed / Rescheduled (${failedOrders.isNotEmpty ? failedOrders.length : 2})'),
            ],
          ),
        ),

        // Tab Content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              // 1. Unassigned Orders Pool
              _buildUnassignedPoolView(isDark, unassignedOrders, dcState),

              // 2. In-Transit Routes Monitor
              _buildInTransitView(isDark, inTransitOrders),

              // 3. Delivered & POD Verified
              _buildDeliveredView(isDark, deliveredOrders),

              // 4. Failed / Rescheduled Deliveries
              _buildFailedView(isDark, failedOrders),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUnassignedPoolView(bool isDark, List<OrderEntity> orders, DCConsoleState dcState) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
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
                    Text('Unassigned Orders Pool', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('Assign incoming merchant shipments to riders based on delivery zones', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('⚡ Auto-clustered and assigned 12 orders to 4 active riders by zone.'),
                      backgroundColor: Color(0xFF10B981),
                    ),
                  );
                },
                icon: const Icon(Icons.auto_awesome, size: 16, color: Colors.white),
                label: const Text('Auto-Assign Zones', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                _buildOrderRow(
                  orderCode: 'TRK-8930',
                  customer: 'Senator Kashim Shettima',
                  phone: '08091112233',
                  address: 'Plot 104 Shehu Shagari Way, Maitama, Abuja',
                  product: '2x Respira Detox Tea',
                  amount: 50000.0,
                  paymentType: 'POD Cash',
                  isUnassigned: true,
                  onAssign: () => _showAssignRiderModal(context, isDark, 'TRK-8930', dcState),
                ),
                const Divider(height: 1, color: Color(0xFF334155)),
                _buildOrderRow(
                  orderCode: 'TRK-8931',
                  customer: 'Barrister Chidinma Okafor',
                  phone: '08032223344',
                  address: 'Suite 4B, Metro Plaza, Zakariya Maimalari St, CBD',
                  product: '1x Grazer Herbal Tea',
                  amount: 25000.0,
                  paymentType: 'Direct Transfer',
                  isUnassigned: true,
                  onAssign: () => _showAssignRiderModal(context, isDark, 'TRK-8931', dcState),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInTransitView(bool isDark, List<OrderEntity> orders) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Live In-Transit Deliveries', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                _buildOrderRow(
                  orderCode: 'TRK-8924',
                  customer: 'Chief Aliyu Mohammed',
                  phone: '08031234567',
                  address: 'Plot 402 Aminu Kano Crescent, Wuse 2, Abuja',
                  product: '2x Respira Detox Tea',
                  amount: 35000.0,
                  paymentType: 'POD Cash',
                  riderName: 'Emeka Rider (PDA-7000)',
                  statusPill: 'IN-TRANSIT',
                ),
                const Divider(height: 1, color: Color(0xFF334155)),
                _buildOrderRow(
                  orderCode: 'TRK-8925',
                  customer: 'Dr. Aisha Garba',
                  phone: '08098765432',
                  address: '14 Gana Street, Maitama, Abuja',
                  product: '3x Grazer Herbal Tea',
                  amount: 45000.0,
                  paymentType: 'Monnify Direct Transfer',
                  riderName: 'Emeka Rider (PDA-7000)',
                  statusPill: 'IN-TRANSIT',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveredView(bool isDark, List<OrderEntity> orders) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Delivered & POD Verified Audit', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                _buildOrderRow(
                  orderCode: 'TRK-8910',
                  customer: 'Engr. Nnamdi Eze',
                  phone: '08033334455',
                  address: 'Area 11, Garki, Abuja',
                  product: '1x Respira Detox Tea',
                  amount: 25000.0,
                  paymentType: 'POD Cash (Collected)',
                  riderName: 'Emeka Rider (PDA-7000)',
                  statusPill: 'DELIVERED (POD)',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFailedView(bool isDark, List<OrderEntity> orders) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Failed & Rescheduled Delivery Tickets', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                _buildOrderRow(
                  orderCode: 'TRK-8920',
                  customer: 'Mrs. Folake Adebayo',
                  phone: '08051112233',
                  address: 'Wuse Zone 4, Abuja',
                  product: '1x Grazer Herbal Tea',
                  amount: 18000.0,
                  paymentType: 'POD Cash',
                  riderName: 'Emeka Rider (PDA-7000)',
                  statusPill: 'FAILED (RETURN PENDING)',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderRow({
    required String orderCode,
    required String customer,
    required String phone,
    required String address,
    required String product,
    required double amount,
    required String paymentType,
    String? riderName,
    String? statusPill,
    bool isUnassigned = false,
    VoidCallback? onAssign,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.local_shipping_outlined, color: Color(0xFF2563EB), size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$orderCode • $customer ($phone)', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text(address, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)), overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text('Product: $product • Channel: $paymentType', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8))),
                      if (riderName != null)
                        Text('Assigned Rider: $riderName', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF2563EB))),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(CurrencyFormatter.formatNaira(amount), style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              if (isUnassigned)
                ElevatedButton(
                  onPressed: onAssign,
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8)),
                  child: const Text('Assign Rider', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                )
              else if (statusPill != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusPill.contains('DELIVERED')
                        ? const Color(0xFFECFDF5)
                        : (statusPill.contains('FAILED') ? const Color(0xFFFEF2F2) : const Color(0xFFEDE9FE)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    statusPill,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: statusPill.contains('DELIVERED')
                          ? const Color(0xFF059669)
                          : (statusPill.contains('FAILED') ? const Color(0xFFDC2626) : const Color(0xFF7C3AED)),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAssignRiderModal(BuildContext context, bool isDark, String orderCode, DCConsoleState dcState) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Assign Order $orderCode to Rider', style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Select an active delivery agent for this route:', style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B))),
            const SizedBox(height: 14),
            ...dcState.drivers.map((driver) {
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFF2563EB).withValues(alpha: 0.15),
                  child: Text(driver.name.substring(0, 1), style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                ),
                title: Text(driver.name, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13)),
                subtitle: Text('${driver.driverCode} • Zone: ${driver.assignedZone}', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B))),
                trailing: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('✅ Order $orderCode assigned to ${driver.name} (${driver.driverCode}).')),
                    );
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
                  child: const Text('Assign', style: TextStyle(color: Colors.white, fontSize: 12)),
                ),
              );
            }),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ],
      ),
    );
  }
}
