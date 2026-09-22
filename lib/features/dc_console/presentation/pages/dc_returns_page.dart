import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/helpers/formatters.dart';
import '../../../../core/widgets/app_skeleton_loader.dart';
import '../../../client_portal/presentation/widgets/pangea_excel_data_table.dart';
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
          else if (isCompact)
            _buildReturnsCards(context, dcState.returnItems, isDark, dcNotifier)
          else
            _buildReturnsExcelTable(context, dcState.returnItems, isDark, dcNotifier),
        ],
      ),
    );
  }

  Widget _buildReturnsCards(
    BuildContext context,
    List<DCReturnItem> items,
    bool isDark,
    DCConsoleNotifier dcNotifier,
  ) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      itemBuilder: (ctx, i) {
        final item = items[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(14),
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
                  _buildStatusBadge(item.qcStatus),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Product: ${item.productName} (Qty: ${item.quantity}) • Value: ${CurrencyFormatter.formatNaira(item.amount)}',
                style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B)),
              ),
              Text(
                'Customer: ${item.customerName} • Rider: ${item.riderName}',
                style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
              ),
              Text(
                'Return Reason: "${item.returnReason}"',
                style: GoogleFonts.inter(fontSize: 12, fontStyle: FontStyle.italic, color: const Color(0xFFF59E0B)),
              ),
              if (item.qcStatus == 'pending_qc') ...[
                const SizedBox(height: 14),
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
    );
  }

  Widget _buildReturnsExcelTable(
    BuildContext context,
    List<DCReturnItem> items,
    bool isDark,
    DCConsoleNotifier dcNotifier,
  ) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: PangeaExcelDataTable<DCReturnItem>(
        items: items,
        brandPrimary: const Color(0xFF2563EB),
        enablePagination: true,
        initialPageSize: 20,
        rowHeight: 46,
        columns: [
          ExcelColumnDef<DCReturnItem>(
            key: 'ticket',
            group: 'Return Info',
            label: 'TICKET #',
            defaultWidth: 140,
            minWidth: 110,
            searchString: (item) => item.returnTicketNumber,
            sortValue: (item) => item.returnTicketNumber,
            cellBuilder: (context, item, row, isDark, brand) => Text(
              item.returnTicketNumber,
              style: GoogleFonts.jetBrainsMono(
                fontWeight: FontWeight.bold,
                fontSize: 11.5,
                color: const Color(0xFF2563EB),
              ),
            ),
          ),
          ExcelColumnDef<DCReturnItem>(
            key: 'orderNumber',
            group: 'Return Info',
            label: 'ORDER #',
            defaultWidth: 140,
            minWidth: 110,
            searchString: (item) => item.orderNumber,
            sortValue: (item) => item.orderNumber,
            cellBuilder: (context, item, row, isDark, brand) => Text(
              item.orderNumber,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
          ),
          ExcelColumnDef<DCReturnItem>(
            key: 'product',
            group: 'Inventory',
            label: 'PRODUCT & QTY',
            defaultWidth: 180,
            minWidth: 140,
            searchString: (item) => '${item.productName} ${item.quantity}',
            sortValue: (item) => item.productName,
            cellBuilder: (context, item, row, isDark, brand) => Text(
              '${item.productName} (x${item.quantity})',
              style: TextStyle(
                fontSize: 11.5,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          ExcelColumnDef<DCReturnItem>(
            key: 'customer',
            group: 'Customer',
            label: 'CUSTOMER',
            defaultWidth: 180,
            minWidth: 140,
            searchString: (item) => '${item.customerName} ${item.customerPhone}',
            sortValue: (item) => item.customerName,
            cellBuilder: (context, item, row, isDark, brand) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  item.customerName,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  item.customerPhone,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10.5,
                    color: const Color(0xFF64748B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          ExcelColumnDef<DCReturnItem>(
            key: 'rider',
            group: 'Logistics',
            label: 'CUSTODY RIDER',
            defaultWidth: 150,
            minWidth: 120,
            searchString: (item) => item.riderName,
            sortValue: (item) => item.riderName,
            cellBuilder: (context, item, row, isDark, brand) => Text(
              item.riderName,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white70 : const Color(0xFF334155),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          ExcelColumnDef<DCReturnItem>(
            key: 'reason',
            group: 'Reason',
            label: 'RETURN REASON',
            defaultWidth: 180,
            minWidth: 130,
            searchString: (item) => item.returnReason,
            sortValue: (item) => item.returnReason,
            cellBuilder: (context, item, row, isDark, brand) => Text(
              '"${item.returnReason}"',
              style: const TextStyle(
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: Color(0xFFF59E0B),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          ExcelColumnDef<DCReturnItem>(
            key: 'amount',
            group: 'Financial',
            label: 'VALUE (₦)',
            defaultWidth: 130,
            minWidth: 100,
            searchString: (item) => '${item.amount}',
            sortValue: (item) => item.amount,
            cellBuilder: (context, item, row, isDark, brand) => Text(
              CurrencyFormatter.formatNaira(item.amount),
              style: GoogleFonts.jetBrainsMono(
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
          ),
          ExcelColumnDef<DCReturnItem>(
            key: 'status',
            group: 'Status',
            label: 'QC STATUS',
            defaultWidth: 150,
            minWidth: 120,
            searchString: (item) => item.qcStatus,
            sortValue: (item) => item.qcStatus,
            cellBuilder: (context, item, row, isDark, brand) => _buildStatusBadge(item.qcStatus),
          ),
          ExcelColumnDef<DCReturnItem>(
            key: 'actions',
            group: 'Actions',
            label: 'QC ACTION',
            defaultWidth: 230,
            minWidth: 190,
            cellBuilder: (context, item, row, isDark, brand) {
              if (item.qcStatus == 'pending_qc') {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: () {
                        dcNotifier.gradeReturn(item.id, 'grade_b_scrapped', null);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('⚠️ Logged to Damaged / Scrap write-off ledger.')),
                        );
                      },
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFFCA5A5)),
                        ),
                        child: const Text(
                          'Scrap (B)',
                          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFFDC2626)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: () {
                        dcNotifier.gradeReturn(item.id, 'grade_a_restocked', 'BIN-A1-04');
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('✅ Grade A verified: Item restocked into Warehouse BIN-A1-04.'),
                            backgroundColor: Color(0xFF10B981),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Restock (A)',
                          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                );
              }
              return Text(
                item.qcStatus == 'grade_a_restocked' ? 'Restocked to BIN' : 'Scrapped',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10.5,
                  color: isDark ? Colors.white54 : const Color(0xFF94A3B8),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String qcStatus) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: qcStatus == 'grade_a_restocked'
            ? const Color(0xFFECFDF5)
            : (qcStatus == 'grade_b_scrapped' ? const Color(0xFFFEF2F2) : const Color(0xFFFEF3C7)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        qcStatus.toUpperCase().replaceAll('_', ' '),
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: qcStatus == 'grade_a_restocked'
              ? const Color(0xFF059669)
              : (qcStatus == 'grade_b_scrapped' ? const Color(0xFFDC2626) : const Color(0xFFD97706)),
        ),
      ),
    );
  }
}
