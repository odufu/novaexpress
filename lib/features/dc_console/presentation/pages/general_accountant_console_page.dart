import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';

import '../../../../core/helpers/formatters.dart';
import '../../../../core/services/signature_storage_service.dart';
import '../../../client_portal/domain/entities/client_settlement.dart';
import '../../../finance/domain/entities/remittance.dart';
import '../../../finance/presentation/providers/finance_provider.dart';
import '../../domain/entities/dc_fleet_driver.dart';
import '../../domain/entities/distribution_center.dart';
import '../providers/dc_console_provider.dart';

class GeneralAccountantConsolePage extends ConsumerStatefulWidget {
  const GeneralAccountantConsolePage({super.key});

  @override
  ConsumerState<GeneralAccountantConsolePage> createState() =>
      _GeneralAccountantConsolePageState();
}

class _GeneralAccountantConsolePageState
    extends ConsumerState<GeneralAccountantConsolePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  List<ClientSettlement> _settlements = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadNationalData();
    });
  }

  Future<void> _loadNationalData() async {
    ref.read(dcConsoleProvider.notifier).loadDistributionCentersFromDatabase();
    ref.read(dcConsoleProvider.notifier).loadDriversFromDatabase();
    ref.read(dcConsoleProvider.notifier).loadClientsFromDatabase();
    ref.read(dcConsoleProvider.notifier).loadTransactionsFromDatabase();
    final activeHubId = ref.read(dcConsoleProvider).activeHubId;
    ref.read(financeProvider.notifier).loadRemittances(activeHubId);
    try {
      final fetched = await ref.read(dcConsoleProvider.notifier).fetchDcClientSettlements();
      if (mounted) {
        setState(() => _settlements = fetched);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final dcState = ref.watch(dcConsoleProvider);
    final financeState = ref.watch(financeProvider);

    final dcs = dcState.distributionCenters;
    final drivers = dcState.drivers;
    final settlements = _settlements;
    final remittances = financeState.remittances;

    // National Aggregated Financials
    final double totalFieldCashLiability = drivers.fold(
      0.0,
      (sum, d) => sum + (d.cashInCustody > 0 ? d.cashInCustody : 0.0),
    );
    final double totalRemittancesCleared = remittances
        .where((r) => !r.isPending)
        .fold(0.0, (sum, r) => sum + r.amount);
    final double totalMerchantPayable = settlements
        .where((s) => s.status.toLowerCase() != 'completed')
        .fold(0.0, (sum, s) => sum + s.netPayoutAmount);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B132B) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        elevation: 0.5,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'General Accountant Console',
              style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              'National Financial Oversight • DC Audits & Merchant Disbursements',
              style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF00522A), fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh National Ledger',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadNationalData,
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF00522A),
          unselectedLabelColor: const Color(0xFF64748B),
          indicatorColor: const Color(0xFF00522A),
          indicatorWeight: 3,
          labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
          unselectedLabelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
          tabs: [
            Tab(
              icon: const Icon(Icons.hub_outlined, size: 18),
              text: 'Station Breakdown (${dcs.length} DCs)',
            ),
            Tab(
              icon: const Icon(Icons.payments_outlined, size: 18),
              text: 'Merchant Settlements (${settlements.length})',
            ),
            Tab(
              icon: const Icon(Icons.account_balance_outlined, size: 18),
              text: 'National Cash Ledger (${remittances.length})',
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // National Financial KPIs
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildKpiCard(
                    'NATIONAL FIELD LIABILITY',
                    CurrencyFormatter.formatNaira(totalFieldCashLiability),
                    '${drivers.where((d) => d.cashInCustody > 0).length} riders with cash in hand',
                    Icons.payments_rounded,
                    const Color(0xFFEA580C),
                    isDark,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildKpiCard(
                    'CLEARED REMITTANCES',
                    CurrencyFormatter.formatNaira(totalRemittancesCleared),
                    'Verified & banked into DC treasury',
                    Icons.verified_rounded,
                    const Color(0xFF16A34A),
                    isDark,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildKpiCard(
                    'MERCHANT PAYABLE DUE',
                    CurrencyFormatter.formatNaira(totalMerchantPayable),
                    'Net payable across clients',
                    Icons.account_balance_wallet_rounded,
                    const Color(0xFF2563EB),
                    isDark,
                  ),
                ),
              ],
            ),
          ),

          // Main Tabs
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // 1. MULTI-STATION BREAKDOWN
                _buildMultiStationView(dcs, drivers, isDark),

                // 2. MERCHANT RECONCILIATIONS & PAYOUTS
                _buildMerchantSettlementsView(settlements, isDark),

                // 3. NATIONAL CASH AUDIT LEDGER
                _buildNationalLedgerView(remittances, drivers, isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard(
    String label,
    String value,
    String subtitle,
    IconData icon,
    Color color,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.12 : 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    color: color,
                    letterSpacing: 0.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            subtitle,
            style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF64748B)),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 1: MULTI-STATION BREAKDOWN
  // ==========================================
  Widget _buildMultiStationView(
    List<DistributionCenter> dcs,
    List<DCFleetDriver> drivers,
    bool isDark,
  ) {
    if (dcs.isEmpty) {
      return const Center(child: Text('No Distribution Centers found.'));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: dcs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final dc = dcs[index];
        final stationDrivers = drivers.where((d) => d.distributionCenterId == dc.id).toList();
        final stationCashLiability = stationDrivers.fold(
          0.0,
          (sum, d) => sum + (d.cashInCustody > 0 ? d.cashInCustody : 0.0),
        );

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF00522A).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.warehouse_rounded, color: Color(0xFF00522A), size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          dc.name,
                          style: GoogleFonts.inter(fontSize: 14.5, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            dc.code,
                            style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF2563EB)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${dc.city}, ${dc.state} • ${stationDrivers.length} Active Fleet Drivers',
                      style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    CurrencyFormatter.formatNaira(stationCashLiability),
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: stationCashLiability > 0 ? const Color(0xFFEA580C) : const Color(0xFF16A34A),
                    ),
                  ),
                  Text(
                    stationCashLiability > 0 ? 'Field Cash Held' : 'Zero Liability ✓',
                    style: GoogleFonts.inter(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: stationCashLiability > 0 ? const Color(0xFFEA580C) : const Color(0xFF16A34A),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ==========================================
  // TAB 2: MERCHANT SETTLEMENTS & PAYOUTS
  // ==========================================
  Widget _buildMerchantSettlementsView(
    List<ClientSettlement> settlements,
    bool isDark,
  ) {
    if (settlements.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.assignment_turned_in_outlined, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text('No Client Settlement Batches', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 4),
            const Text('Daily merchant reconciliation runs automatically at 18:00 DC operational cutoff.'),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: settlements.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final s = settlements[index];
        final isCompleted = s.status.toLowerCase() == 'completed';

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isCompleted
                  ? (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))
                  : const Color(0xFF2563EB).withValues(alpha: 0.4),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.receipt_long_rounded, color: Color(0xFF2563EB), size: 18),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        s.settlementNumber,
                        style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isCompleted
                          ? const Color(0xFF16A34A).withValues(alpha: 0.1)
                          : const Color(0xFF2563EB).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      s.status.toUpperCase(),
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isCompleted ? const Color(0xFF16A34A) : const Color(0xFF2563EB),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Gross COD Sales:', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B))),
                      Text(CurrencyFormatter.formatNaira(s.grossCollections), style: GoogleFonts.jetBrainsMono(fontSize: 12.5, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Logistics Fees:', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B))),
                      Text('-${CurrencyFormatter.formatNaira(s.logisticsFeesDeducted)}', style: GoogleFonts.jetBrainsMono(fontSize: 12.5, fontWeight: FontWeight.bold, color: const Color(0xFFDC2626))),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Net Payout Due:', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B))),
                      Text(
                        CurrencyFormatter.formatNaira(s.netPayoutAmount),
                        style: GoogleFonts.jetBrainsMono(fontSize: 14, fontWeight: FontWeight.w900, color: const Color(0xFF16A34A)),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 10),

              // Bank details
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Bank: ${s.destinationBankName} • ${s.destinationAccountNumber}',
                    style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
                  ),
                  if (!isCompleted)
                    ElevatedButton.icon(
                      onPressed: () => _openProcessPayoutModal(context, s, isDark),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00522A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.send_rounded, size: 14),
                      label: const Text('Disburse Payout', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
                    ),
                  if (isCompleted && s.proofOfPaymentUrl != null)
                    TextButton.icon(
                      onPressed: () => _viewAdviceModal(context, s.proofOfPaymentUrl!),
                      icon: const Icon(Icons.visibility_outlined, size: 14),
                      label: const Text('View Payment Advice', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ==========================================
  // TAB 3: NATIONAL AUDIT LEDGER
  // ==========================================
  Widget _buildNationalLedgerView(
    List<RemittanceEntity> remittances,
    List<DCFleetDriver> drivers,
    bool isDark,
  ) {
    if (remittances.isEmpty) {
      return const Center(child: Text('No national remittances recorded yet.'));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: remittances.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final rem = remittances[index];
        final driver = drivers.where((d) => d.id == rem.deliveryAgentId || d.driverCode == rem.deliveryAgentId).firstOrNull;
        final riderName = driver != null ? driver.name : (rem.payerName?.isNotEmpty == true ? rem.payerName! : 'Fleet Rider');

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: rem.isPending
                      ? const Color(0xFFEA580C).withValues(alpha: 0.1)
                      : const Color(0xFF16A34A).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  rem.isPending ? Icons.hourglass_top_rounded : Icons.check_circle_rounded,
                  size: 20,
                  color: rem.isPending ? const Color(0xFFEA580C) : const Color(0xFF16A34A),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      riderName,
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Ref: ${rem.referenceNumber.isNotEmpty ? rem.referenceNumber : rem.id.substring(0, 8)} • ${DateFormat('dd MMM yyyy, hh:mm a').format(rem.createdAt)}',
                      style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    CurrencyFormatter.formatNaira(rem.amount),
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: rem.isPending ? const Color(0xFFEA580C) : const Color(0xFF16A34A),
                    ),
                  ),
                  Text(
                    rem.isPending ? 'Pending Audit' : 'Banked & Verified',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: rem.isPending ? const Color(0xFFEA580C) : const Color(0xFF16A34A),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ==========================================
  // PROCESS PAYOUT MODAL
  // ==========================================
  void _openProcessPayoutModal(
    BuildContext context,
    ClientSettlement settlement,
    bool isDark,
  ) {
    final refController = TextEditingController();
    String? proofUrl;
    bool isUploading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          insetPadding: const EdgeInsets.all(16),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 480),
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Process Merchant Payout', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // NUBAN Account Card
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Bank:', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
                            Text(settlement.destinationBankName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Account Number:', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
                            Row(
                              children: [
                                Text(settlement.destinationAccountNumber, style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF2563EB))),
                                const SizedBox(width: 6),
                                InkWell(
                                  onTap: () {
                                    Clipboard.setData(ClipboardData(text: settlement.destinationAccountNumber));
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Account copied!')));
                                  },
                                  child: const Icon(Icons.copy_rounded, size: 14, color: Color(0xFF2563EB)),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Account Name:', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
                            Text(settlement.destinationAccountName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                          ],
                        ),
                        const Divider(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Net Amount to Transfer:', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
                            Text(CurrencyFormatter.formatNaira(settlement.netPayoutAmount), style: GoogleFonts.jetBrainsMono(fontSize: 15, fontWeight: FontWeight.w900, color: const Color(0xFF16A34A))),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Upload Payment Advice / Debit Slip
                  Text('Upload Bank Debit Confirmation Slip', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () async {
                      try {
                        final result = await FilePickerPlatform.instance.pickFiles(type: FileType.custom, allowedExtensions: ['jpg', 'png', 'pdf']);
                        if (result.isNotEmpty) {
                          final file = result.first;
                          final bytes = await file.readAsBytes();
                          if (bytes.isNotEmpty) {
                            setModalState(() => isUploading = true);
                            final url = await SignatureStorageService.uploadSettlementReceipt(
                              bytes: bytes,
                              settlementNumber: settlement.settlementNumber,
                              extension: file.extension ?? 'png',
                            );
                            setModalState(() {
                              proofUrl = url;
                              isUploading = false;
                            });
                          }
                        }
                      } catch (e) {
                        setModalState(() => isUploading = false);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: proofUrl != null ? const Color(0xFF16A34A) : const Color(0xFFCBD5E1)),
                      ),
                      child: isUploading
                          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                          : Row(
                              children: [
                                Icon(proofUrl != null ? Icons.check_circle_rounded : Icons.upload_file_rounded, color: proofUrl != null ? const Color(0xFF16A34A) : const Color(0xFF64748B)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    proofUrl != null ? 'Payment Advice Attached ✓' : 'Tap to attach bank payment receipt (PNG/PDF)',
                                    style: TextStyle(fontSize: 12, color: proofUrl != null ? const Color(0xFF16A34A) : Colors.grey),
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Bank Reference
                  Text('Bank Payment Reference (Narration)', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: refController,
                    decoration: InputDecoration(
                      hintText: 'e.g. TRF-FIRSTBANK-901823',
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Confirm Payout
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00522A),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: const Color(0xFF16A34A),
                            content: Text('Disbursement of ${CurrencyFormatter.formatNaira(settlement.netPayoutAmount)} recorded successfully!'),
                          ),
                        );
                        _loadNationalData();
                      },
                      child: const Text('Confirm Disbursement & Clear Settlement', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _viewAdviceModal(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        child: Image.network(url, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Padding(padding: EdgeInsets.all(20), child: Text('Could not load payment advice.'))),
      ),
    );
  }
}
