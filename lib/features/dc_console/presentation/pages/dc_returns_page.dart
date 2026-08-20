import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/helpers/formatters.dart';
import '../providers/dc_console_provider.dart';

class DCReturnsPage extends ConsumerWidget {
  const DCReturnsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final dcState = ref.watch(dcConsoleProvider);
    final dcNotifier = ref.read(dcConsoleProvider.notifier);

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
                    Text('Customer Returns & QC Grading Desk', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('Inspect returned customer packages, grade restockability and clear rider return custody', style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B))),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Return Tickets List
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: dcState.returnItems.length,
            itemBuilder: (ctx, i) {
              final item = dcState.returnItems[i];
              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF151D36) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${item.returnTicketNumber} • Order ${item.orderNumber}',
                          style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: item.qcStatus == 'grade_a_restocked'
                                ? const Color(0xFFECFDF5)
                                : (item.qcStatus == 'grade_b_scrapped' ? const Color(0xFFFEF2F2) : const Color(0xFFFEF3C7)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            item.qcStatus.toUpperCase().replaceAll('_', ' '),
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: item.qcStatus == 'grade_a_restocked'
                                  ? const Color(0xFF059669)
                                  : (item.qcStatus == 'grade_b_scrapped' ? const Color(0xFFDC2626) : const Color(0xFFD97706)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('Product: ${item.productName} (Qty: ${item.quantity}) • Value: ${CurrencyFormatter.formatNaira(item.amount)}', style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B))),
                    Text('Customer: ${item.customerName} • Rider: ${item.riderName}', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8))),
                    Text('Return Reason: "${item.returnReason}"', style: GoogleFonts.inter(fontSize: 12, fontStyle: FontStyle.italic, color: const Color(0xFFF59E0B))),
                    const SizedBox(height: 14),

                    if (item.qcStatus == 'pending_qc') ...[
                      const Divider(height: 1, color: Color(0xFF334155)),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () {
                              dcNotifier.gradeReturn(item.id, 'grade_b_scrapped', null);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('⚠️ Logged to Damaged / Scrap write-off ledger.')),
                              );
                            },
                            icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFEF4444)),
                            label: const Text('Grade B (Scrap)', style: TextStyle(color: Color(0xFFEF4444))),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton.icon(
                            onPressed: () {
                              dcNotifier.gradeReturn(item.id, 'grade_a_restocked', 'BIN-A1-04');
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('✅ Grade A verified: Item restocked into Warehouse BIN-A1-04.'),
                                  backgroundColor: Color(0xFF10B981),
                                ),
                              );
                            },
                            icon: const Icon(Icons.inventory_rounded, size: 16, color: Colors.white),
                            label: const Text('Grade A (Restock to Bin)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
