import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/helpers/formatters.dart';
import '../../../../core/widgets/app_skeleton_loader.dart';
import '../providers/dc_console_provider.dart';

class DCReturnsPage extends ConsumerWidget {
  const DCReturnsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final dcState = ref.watch(dcConsoleProvider);
    final dcNotifier = ref.read(dcConsoleProvider.notifier);
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 700;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isCompact ? 14 : 20),
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
                      'Customer Returns & QC Grading Desk',
                      style: GoogleFonts.inter(fontSize: isCompact ? 18 : 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Inspect returned customer packages, grade restockability and clear rider return custody',
                      style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Return Tickets List
          if (dcState.isLoading)
            Column(
              children: List.generate(3, (index) => const StockCardSkeleton()),
            )
          else if (dcState.returnItems.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 40),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF151D36) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  const Icon(Icons.assignment_turned_in_outlined, size: 44, color: Color(0xFF10B981)),
                  const SizedBox(height: 10),
                  Text('No Pending Return Tickets', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('All returned orders have been graded and cleared from transit.', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
                ],
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: dcState.returnItems.length,
              itemBuilder: (ctx, i) {
                final item = dcState.returnItems[i];
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: EdgeInsets.all(isCompact ? 14 : 18),
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
                          Expanded(
                            child: Text(
                              '${item.returnTicketNumber} • Order ${item.orderNumber}',
                              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
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
                        Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                        const SizedBox(height: 12),
                        Wrap(
                          alignment: WrapAlignment.end,
                          spacing: 10,
                          runSpacing: 8,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () {
                                dcNotifier.gradeReturn(item.id, 'grade_b_scrapped', null);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('⚠️ Logged to Damaged / Scrap write-off ledger.')),
                                );
                              },
                              icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFEF4444)),
                              label: const Text('Grade B (Scrap)', style: TextStyle(color: Color(0xFFEF4444), fontSize: 12)),
                            ),
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
                              label: const Text('Grade A (Restock to Bin)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
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
