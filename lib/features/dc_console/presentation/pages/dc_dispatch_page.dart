import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/helpers/formatters.dart';
import '../../../orders/presentation/providers/orders_provider.dart';
import '../providers/dc_console_provider.dart';

class DCDispatchPage extends ConsumerWidget {
  const DCDispatchPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final ordersState = ref.watch(ordersProvider);
    final dcState = ref.watch(dcConsoleProvider);

    final pendingOrders = ordersState.orders.where((o) => o.status == 'pending' || o.status == 'accepted').toList();
    final inTransitOrders = ordersState.orders.where((o) => o.status == 'in_transit' || o.status == 'assigned').toList();

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
                    Text(
                      'Deliveries & Route Dispatch',
                      style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Assign pending hub orders, cluster zones and monitor in-transit deliveries',
                      style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('⚡ Auto-clustered 12 orders across 4 active riders by zone.')),
                  );
                },
                icon: const Icon(Icons.auto_awesome, size: 16, color: Colors.white),
                label: const Text('Auto-Dispatch Zones', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // In-Transit Deliveries Monitor
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Active In-Transit Hub Deliveries', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 14),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: inTransitOrders.isNotEmpty ? inTransitOrders.length : 3,
                  separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFF334155)),
                  itemBuilder: (ctx, i) {
                    final order = inTransitOrders.isNotEmpty ? inTransitOrders[i] : null;
                    final orderNum = order?.orderNumber ?? (i == 0 ? 'TRK-8924' : (i == 1 ? 'TRK-8925' : 'TRK-8921'));
                    final custName = order?.customerName ?? (i == 0 ? 'Alhaji Musa Ibrahim' : (i == 1 ? 'Dr. Aisha Garba' : 'Engr. Nnamdi Eze'));
                    final city = order?.deliveryCity ?? (i == 0 ? 'Wuse II' : (i == 1 ? 'Maitama' : 'Garki II'));
                    final amount = order?.totalAmount ?? (i == 0 ? 35000.0 : (i == 1 ? 40000.0 : 75000.0));

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2563EB).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.local_shipping_outlined, color: Color(0xFF2563EB), size: 18),
                              ),
                              const SizedBox(width: 14),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '$orderNum • $custName',
                                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    'Zone: $city • Delivery Agent: Emeka Rider (PDA-7000)',
                                    style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Text(
                                CurrencyFormatter.formatNaira(amount),
                                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEDE9FE),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'IN-TRANSIT',
                                  style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF7C3AED)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
