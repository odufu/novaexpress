import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../../core/helpers/formatters.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../client_portal/presentation/widgets/pangea_excel_data_table.dart';
import '../../../domain/entities/admin_models.dart';
import '../../providers/admin_console_provider.dart';
import '../../widgets/admin_metric_card.dart';

class AdminSettlementReconciliationTab extends ConsumerWidget {
  const AdminSettlementReconciliationTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(adminConsoleProvider);
    final notifier = ref.read(adminConsoleProvider.notifier);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final reconciliations = state.settlementReconciliations;
    final todayRec = reconciliations.isNotEmpty ? reconciliations.first : null;

    final totalSettledNaira = reconciliations
        .where((r) => r.isSettled)
        .fold<double>(0.0, (sum, r) => sum + r.totalNetMerchantPayout);

    // Columns definition for PangeaExcelDataTable
    final columns = <ExcelColumnDef<AdminSettlementReconciliation>>[
      // 1. Date & Batch
      ExcelColumnDef<AdminSettlementReconciliation>(
        key: 'date',
        label: 'Settlement Batch Date',
        defaultWidth: 190,
        minWidth: 150,
        sortValue: (r) => r.date.millisecondsSinceEpoch,
        searchString: (r) => DateFormat('yyyy-MM-dd EEEE MMMM').format(r.date),
        cellBuilder: (ctx, rec, idx, dark, primary) {
          return Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.receipt_long_rounded, color: Color(0xFF6366F1), size: 15),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  DateFormat('EEE, MMM d, y').format(rec.date),
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: dark ? Colors.white : const Color(0xFF0F172A),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          );
        },
      ),

      // 2. Volume & Scale
      ExcelColumnDef<AdminSettlementReconciliation>(
        key: 'volume',
        label: 'Orders & Participants',
        defaultWidth: 200,
        minWidth: 160,
        sortValue: (r) => r.totalOrdersSettled,
        cellBuilder: (ctx, rec, idx, dark, primary) {
          return Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '${rec.totalOrdersSettled} orders • ${rec.participatingAgentsCount} agents • ${rec.participatingMerchantsCount} merchants',
              style: GoogleFonts.inter(fontSize: 11, color: dark ? Colors.white70 : const Color(0xFF64748B)),
              overflow: TextOverflow.ellipsis,
            ),
          );
        },
      ),

      // 3. Gross COD Ingested
      ExcelColumnDef<AdminSettlementReconciliation>(
        key: 'gross_cod',
        label: 'Gross COD Ingested',
        defaultWidth: 160,
        minWidth: 120,
        align: TextAlign.right,
        sortValue: (r) => r.totalGrossCodCollected,
        cellBuilder: (ctx, rec, idx, dark, primary) {
          return Align(
            alignment: Alignment.centerRight,
            child: Text(
              CurrencyFormatter.formatNaira(rec.totalGrossCodCollected),
              style: GoogleFonts.jetBrainsMono(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: dark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
          );
        },
      ),

      // 4. Logistics & Fuel Fees
      ExcelColumnDef<AdminSettlementReconciliation>(
        key: 'deductions',
        label: 'Courier & Fuel Fees',
        defaultWidth: 160,
        minWidth: 120,
        align: TextAlign.right,
        sortValue: (r) => r.totalCourierDeliveryFees + r.totalFuelAllowances,
        cellBuilder: (ctx, rec, idx, dark, primary) {
          final totalDeductions = rec.totalCourierDeliveryFees + rec.totalFuelAllowances;
          return Align(
            alignment: Alignment.centerRight,
            child: Text(
              '-${CurrencyFormatter.formatNaira(totalDeductions)}',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 12,
                color: const Color(0xFFEF4444),
                fontWeight: FontWeight.w600,
              ),
            ),
          );
        },
      ),

      // 5. Platform Commission
      ExcelColumnDef<AdminSettlementReconciliation>(
        key: 'commission',
        label: 'Platform Margin',
        defaultWidth: 140,
        minWidth: 110,
        align: TextAlign.right,
        sortValue: (r) => r.totalPlatformCommissions,
        cellBuilder: (ctx, rec, idx, dark, primary) {
          return Align(
            alignment: Alignment.centerRight,
            child: Text(
              '-${CurrencyFormatter.formatNaira(rec.totalPlatformCommissions)}',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 12,
                color: const Color(0xFF8B5CF6),
                fontWeight: FontWeight.w600,
              ),
            ),
          );
        },
      ),

      // 6. Net Merchant Payout
      ExcelColumnDef<AdminSettlementReconciliation>(
        key: 'net_payout',
        label: 'Net Merchant Payout',
        defaultWidth: 170,
        minWidth: 130,
        align: TextAlign.right,
        sortValue: (r) => r.totalNetMerchantPayout,
        cellBuilder: (ctx, rec, idx, dark, primary) {
          return Align(
            alignment: Alignment.centerRight,
            child: Text(
              CurrencyFormatter.formatNaira(rec.totalNetMerchantPayout),
              style: GoogleFonts.jetBrainsMono(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF10B981),
              ),
            ),
          );
        },
      ),

      // 7. Status
      ExcelColumnDef<AdminSettlementReconciliation>(
        key: 'status',
        label: 'Settlement Status',
        defaultWidth: 160,
        minWidth: 130,
        cellBuilder: (ctx, rec, idx, dark, primary) {
          final settled = rec.isSettled;
          return Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: settled
                    ? const Color(0xFF10B981).withValues(alpha: 0.14)
                    : const Color(0xFFF59E0B).withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                settled ? '✓ SETTLED AT 10PM' : '⏳ AWAITING 10PM',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: settled ? const Color(0xFF059669) : const Color(0xFFD97706),
                ),
              ),
            ),
          );
        },
      ),
    ];

    // Top Toolbar Actions placed beside Settings Button
    final topToolbarActions = <Widget>[
      if (todayRec != null && !todayRec.isSettled)
        ElevatedButton.icon(
          onPressed: () {
            notifier.triggerDaily10pmSettlement();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('✓ 10:00 PM Settlement Batch reconciled and dispatched to merchant banks!'),
                backgroundColor: Color(0xFF10B981),
              ),
            );
          },
          icon: const Icon(Icons.flash_on_rounded, size: 14),
          label: const Text('Execute 10:00 PM Settlement'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6366F1),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
            minimumSize: const Size(0, 32),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            textStyle: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 10:00 PM Settlement Policy Banner (Compact)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withValues(alpha: isDark ? 0.14 : 0.07),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.schedule_rounded, color: Color(0xFF6366F1), size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'NovaXpress Logistics DC Settlement & Merchant Reconciliation Protocol: NovaXpress Platform does not hold custodial funds. NovaXpress Logistics tracks rider cash collections remitted to each DC\'s Bank Account (Abuja DC or Lagos DC). The DC Account Ops records reconciliation, and Merchants approve it before payout disbursement.',
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Metrics Summary (Compact Ribbon by default)
          AdminMetricsHeader(
            metrics: [
              AdminMetricData(
                title: 'Gross COD Ingested',
                value: todayRec != null
                    ? CurrencyFormatter.formatNaira(todayRec.totalGrossCodCollected)
                    : '₦0',
                icon: Icons.payments_outlined,
                iconColor: const Color(0xFF10B981),
                subtitle: 'remitted by agents today',
                tooltip: 'Total cash and direct transfers remitted to DC station accounts from field deliveries',
              ),
              AdminMetricData(
                title: 'Net Merchant Payout',
                value: todayRec != null
                    ? CurrencyFormatter.formatNaira(todayRec.totalNetMerchantPayout)
                    : '₦0',
                icon: Icons.account_balance_wallet_outlined,
                iconColor: const Color(0xFF3B82F6),
                subtitle: 'scheduled for 10:00 PM',
                tooltip: 'Net funds payable to merchant bank accounts after deducting logistics expenses',
              ),
              AdminMetricData(
                title: 'Platform Margin',
                value: todayRec != null
                    ? CurrencyFormatter.formatNaira(todayRec.totalPlatformCommissions)
                    : '₦0',
                icon: Icons.trending_up_rounded,
                iconColor: const Color(0xFF8B5CF6),
                subtitle: 'platform commissions',
                tooltip: 'NovaXpress ecosystem facilitation and warehousing fees retained',
              ),
              AdminMetricData(
                title: 'Total Historical Payouts',
                value: CurrencyFormatter.formatNaira(totalSettledNaira),
                icon: Icons.verified_user_outlined,
                iconColor: AppColors.orange,
                subtitle: 'settled to merchants',
                tooltip: 'Lifetime cumulative cash settlements deposited into merchant bank accounts',
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Excel Data Table with Filters & Actions directly on Header Beside Settings
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
            ),
            child: PangeaExcelDataTable<AdminSettlementReconciliation>(
              items: reconciliations,
              columns: columns,
              brandPrimary: const Color(0xFF6366F1),
              tableHeight: 460,
              initialPageSize: 15,
              showSettingsButton: true,
              topToolbarActions: topToolbarActions,
            ),
          ),
        ],
      ),
    );
  }
}
