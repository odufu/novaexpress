import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/helpers/formatters.dart';
import '../../../../core/widgets/user_avatar_widget.dart';
import '../../../finance/domain/entities/remittance.dart';
import '../../../finance/presentation/providers/finance_provider.dart';
import '../../domain/entities/dc_fleet_driver.dart';
import '../../domain/entities/distribution_center.dart';
import '../providers/dc_console_provider.dart';
import '../widgets/dc_staff_profile_settings_tab.dart';

class DCFinanceOperationsPage extends ConsumerStatefulWidget {
  const DCFinanceOperationsPage({super.key});

  @override
  ConsumerState<DCFinanceOperationsPage> createState() => _DCFinanceOperationsPageState();
}

class _DCFinanceOperationsPageState extends ConsumerState<DCFinanceOperationsPage> {
  int _activeTab = 0; // 0: Approvals Queue, 1: Rider Cash Liabilities, 2: Audit History, 3: Profile & Settings
  final TextEditingController _searchController = TextEditingController();
  String _riderLiabilityFilter = 'all'; // 'all', 'holding_cash', 'high_balance'

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  void _loadData() {
    final activeHubId = ref.read(dcConsoleProvider).activeHubId;
    ref.read(financeProvider.notifier).loadRemittances(activeHubId);
    ref.read(dcConsoleProvider.notifier).loadDriversFromDatabase();
    ref.read(dcConsoleProvider.notifier).loadTransactionsFromDatabase();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final financeState = ref.watch(financeProvider);
    final dcState = ref.watch(dcConsoleProvider);

    final allRemittances = financeState.remittances;
    final pendingRemittances = allRemittances.where((r) => r.isPending).toList();
    final approvedRemittances = allRemittances.where((r) => !r.isPending).toList();

    final allDrivers = dcState.drivers;
    final double totalFieldCashLiability = allDrivers.fold(
      0.0,
      (sum, d) => sum + (d.cashInCustody > 0 ? d.cashInCustody : 0.0),
    );
    final double totalPendingVerification = pendingRemittances.fold(
      0.0,
      (sum, r) => sum + r.amount,
    );

    final now = DateTime.now();
    final double totalApprovedToday = approvedRemittances.where((r) {
      return r.createdAt.year == now.year &&
          r.createdAt.month == now.month &&
          r.createdAt.day == now.day;
    }).fold(0.0, (sum, r) => sum + r.amount);

    final currentDc = dcState.distributionCenters.where((d) => d.id == dcState.activeHubId).firstOrNull ??
        dcState.distributionCenters.firstOrNull;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B132B) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        elevation: 0.5,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Finance Admin Console',
              style: GoogleFonts.inter(fontSize: 17.5, fontWeight: FontWeight.bold),
            ),
            Text(
              '${dcState.activeHubName} • Cash Remittances & Audit',
              style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF00522A), fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh Data',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadData,
          ),
          const SizedBox(width: 8),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
              blurRadius: 14,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: BottomNavigationBar(
            currentIndex: _activeTab,
            onTap: (index) => setState(() => _activeTab = index),
            backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
            selectedItemColor: const Color(0xFF00522A),
            unselectedItemColor: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
            type: BottomNavigationBarType.fixed,
            selectedLabelStyle: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold),
            unselectedLabelStyle: GoogleFonts.inter(fontSize: 11),
            items: [
              BottomNavigationBarItem(
                icon: Badge(
                  isLabelVisible: pendingRemittances.isNotEmpty,
                  label: Text('${pendingRemittances.length}'),
                  backgroundColor: const Color(0xFFEA580C),
                  child: const Icon(Icons.pending_actions_rounded),
                ),
                label: 'Approvals',
              ),
              BottomNavigationBarItem(
                icon: Badge(
                  isLabelVisible: allDrivers.any((d) => d.cashInCustody > 0),
                  label: Text('${allDrivers.where((d) => d.cashInCustody > 0).length}'),
                  backgroundColor: const Color(0xFFDC2626),
                  child: const Icon(Icons.account_balance_wallet_rounded),
                ),
                label: 'Rider Cash',
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.history_rounded),
                label: 'Audit History',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.person_outline_rounded),
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          // KPI Metric Header - Horizontally Scrollable & Overflow-Free (only on Operational Tabs 0, 1, 2)
          if (_activeTab != 3)
            Container(
              height: 84,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
              ),
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  SizedBox(
                    width: 175,
                    child: _buildKpiCard(
                      'PENDING APPROVAL',
                      CurrencyFormatter.formatNaira(totalPendingVerification),
                      '${pendingRemittances.length} submissions waiting',
                      Icons.hourglass_top_rounded,
                      const Color(0xFFEA580C),
                      isDark,
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 185,
                    child: _buildKpiCard(
                      'FIELD CASH LIABILITY',
                      CurrencyFormatter.formatNaira(totalFieldCashLiability),
                      'Held by active fleet riders',
                      Icons.payments_rounded,
                      const Color(0xFFDC2626),
                      isDark,
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 175,
                    child: _buildKpiCard(
                      'CLEARED TODAY',
                      CurrencyFormatter.formatNaira(totalApprovedToday),
                      'Verified & banked',
                      Icons.verified_rounded,
                      const Color(0xFF16A34A),
                      isDark,
                    ),
                  ),
                ],
              ),
            ),

          // Main Tab Body
          Expanded(
            child: _buildActiveTabBody(pendingRemittances, allDrivers, approvedRemittances, currentDc, isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveTabBody(
    List<RemittanceEntity> pendingRemittances,
    List<DCFleetDriver> allDrivers,
    List<RemittanceEntity> approvedRemittances,
    DistributionCenter? currentDc,
    bool isDark,
  ) {
    switch (_activeTab) {
      case 0:
        return _buildApprovalsQueueView(pendingRemittances, allDrivers, isDark);
      case 1:
        return _buildRiderLiabilitiesView(allDrivers, isDark);
      case 2:
        return _buildAuditHistoryView(approvedRemittances, allDrivers, isDark);
      case 3:
        return DCStaffProfileSettingsTab(
          roleBadgeTitle: 'Station Finance Admin',
          departmentLabel: 'FINANCE & CASH REMITTANCES',
          accentColor: const Color(0xFF00522A),
          roleIcon: Icons.account_balance_wallet_rounded,
          station: currentDc,
        );
      default:
        return _buildApprovalsQueueView(pendingRemittances, allDrivers, isDark);
    }
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
  // TAB 1: APPROVALS QUEUE
  // ==========================================
  Widget _buildApprovalsQueueView(
    List<RemittanceEntity> pendingList,
    List<DCFleetDriver> drivers,
    bool isDark,
  ) {
    if (pendingList.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFF16A34A).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_outline_rounded, size: 48, color: Color(0xFF16A34A)),
              ),
              const SizedBox(height: 16),
              Text(
                'Approvals Queue is Clear! 🎉',
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                'No pending rider cash remittances awaiting verification.',
                style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B)),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: pendingList.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final rem = pendingList[index];
        final driver = drivers.where((d) => d.id == rem.deliveryAgentId || d.driverCode == rem.deliveryAgentId).firstOrNull;
        final riderName = driver != null ? driver.name : (rem.payerName?.isNotEmpty == true ? rem.payerName! : 'Fleet Rider');
        final riderCode = driver != null ? driver.driverCode : 'RDR';
        final hasReceipt = rem.depositReceiptUrl != null && rem.depositReceiptUrl!.isNotEmpty;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFEA580C).withValues(alpha: 0.3)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  UserAvatarWidget(fullName: riderName, radius: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                riderName,
                                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF37021).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                riderCode,
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFFF37021),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Submitted ${DateFormat('MMM dd, yyyy • hh:mm a').format(rem.createdAt)}',
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
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF00522A),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEA580C).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          rem.paymentMethodDisplay.toUpperCase(),
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFFEA580C),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 10),

              // Reference and Receipt Attachment indicator
              Row(
                children: [
                  Icon(
                    hasReceipt ? Icons.attachment_rounded : Icons.money_rounded,
                    size: 15,
                    color: hasReceipt ? const Color(0xFF16A34A) : const Color(0xFF64748B),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      hasReceipt ? 'Bank Deposit Receipt Attached ✓' : 'Physical Cash Handover at Station',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: hasReceipt ? const Color(0xFF16A34A) : const Color(0xFF64748B),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    rem.referenceNumber.isNotEmpty ? rem.referenceNumber : 'Ref: N/A',
                    style: GoogleFonts.jetBrainsMono(fontSize: 11, color: const Color(0xFF64748B)),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Action Buttons
              Row(
                children: [
                  if (hasReceipt)
                    OutlinedButton.icon(
                      onPressed: () => _openReceiptViewerModal(context, rem.depositReceiptUrl!, riderName),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.image_outlined, size: 16),
                      label: const Text('View Receipt', style: TextStyle(fontSize: 12)),
                    ),
                  if (hasReceipt) const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _openReviewModal(context, rem, riderName, riderCode, isDark),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00522A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                      label: Text(
                        'Review & Verify (${CurrencyFormatter.formatNaira(rem.amount)})',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                      ),
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
  // TAB 2: RIDER CASH LIABILITIES
  // ==========================================
  Widget _buildRiderLiabilitiesView(List<DCFleetDriver> drivers, bool isDark) {
    var filtered = drivers;
    if (_riderLiabilityFilter == 'holding_cash') {
      filtered = drivers.where((d) => d.cashInCustody > 0).toList();
    } else if (_riderLiabilityFilter == 'high_balance') {
      filtered = drivers.where((d) => d.cashInCustody >= 50000).toList();
    }

    return Column(
      children: [
        // Filter bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
          ),
          child: Row(
            children: [
              _buildFilterPill('All Riders (${drivers.length})', _riderLiabilityFilter == 'all', () {
                setState(() => _riderLiabilityFilter = 'all');
              }),
              const SizedBox(width: 8),
              _buildFilterPill('Holding Cash (${drivers.where((d) => d.cashInCustody > 0).length})', _riderLiabilityFilter == 'holding_cash', () {
                setState(() => _riderLiabilityFilter = 'holding_cash');
              }),
              const SizedBox(width: 8),
              _buildFilterPill('High Liability (>₦50k)', _riderLiabilityFilter == 'high_balance', () {
                setState(() => _riderLiabilityFilter = 'high_balance');
              }),
            ],
          ),
        ),

        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: filtered.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final d = filtered[index];
              final hasLiability = d.cashInCustody > 0;
              final isHigh = d.cashInCustody >= 50000;

              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isHigh
                        ? const Color(0xFFDC2626).withValues(alpha: 0.4)
                        : (hasLiability ? const Color(0xFFF59E0B).withValues(alpha: 0.3) : const Color(0xFFE2E8F0)),
                  ),
                ),
                child: Row(
                  children: [
                    UserAvatarWidget(fullName: d.name, radius: 21),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  d.name,
                                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  d.driverCode,
                                  style: GoogleFonts.jetBrainsMono(fontSize: 9, fontWeight: FontWeight.bold, color: const Color(0xFF2563EB)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(d.phone, style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B))),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          CurrencyFormatter.formatNaira(d.cashInCustody),
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w900,
                            color: isHigh
                                ? const Color(0xFFDC2626)
                                : (hasLiability ? const Color(0xFFEA580C) : const Color(0xFF16A34A)),
                          ),
                        ),
                        Text(
                          hasLiability ? 'Undeposited Cash' : 'Cleared (₦0)',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: hasLiability ? const Color(0xFFEA580C) : const Color(0xFF16A34A),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 10),
                    IconButton(
                      icon: const Icon(Icons.call_outlined, size: 18),
                      tooltip: 'Call Rider',
                      onPressed: () async {
                        final uri = Uri.parse('tel:${d.phone}');
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri);
                        } else {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Could not dial ${d.phone}')),
                            );
                          }
                        }
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ==========================================
  // TAB 3: AUDIT HISTORY
  // ==========================================
  Widget _buildAuditHistoryView(
    List<RemittanceEntity> approvedList,
    List<DCFleetDriver> drivers,
    bool isDark,
  ) {
    if (approvedList.isEmpty) {
      return const Center(child: Text('No historical approved remittances recorded yet.'));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: approvedList.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final rem = approvedList[index];
        final driver = drivers.where((d) => d.id == rem.deliveryAgentId || d.driverCode == rem.deliveryAgentId).firstOrNull;
        final riderName = driver != null ? driver.name : (rem.payerName?.isNotEmpty == true ? rem.payerName! : 'Fleet Rider');
        final riderCode = driver != null ? driver.driverCode : 'RDR';

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
                  color: const Color(0xFF16A34A).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.verified_rounded, size: 20, color: Color(0xFF16A34A)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$riderName ($riderCode)',
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
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
                      color: const Color(0xFF16A34A),
                    ),
                  ),
                  Text(
                    rem.paymentMethodDisplay,
                    style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF64748B)),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterPill(String title, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF00522A) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? const Color(0xFF00522A) : const Color(0xFFCBD5E1)),
        ),
        child: Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 11.5,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // REVIEW & APPROVE MODAL
  // ==========================================
  void _openReviewModal(
    BuildContext context,
    RemittanceEntity rem,
    String riderName,
    String riderCode,
    bool isDark,
  ) {
    final hasReceipt = rem.depositReceiptUrl != null && rem.depositReceiptUrl!.isNotEmpty;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 520),
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Verify Remittance',
                      style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Remittance Summary Card
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      _buildRow('Rider:', '$riderName ($riderCode)'),
                      const Divider(height: 12),
                      _buildRow('Amount to Clear:', CurrencyFormatter.formatNaira(rem.amount), isBold: true, valueColor: const Color(0xFF00522A)),
                      const Divider(height: 12),
                      _buildRow('Channel:', rem.paymentMethodDisplay),
                      const Divider(height: 12),
                      _buildRow('Reference:', rem.referenceNumber.isNotEmpty ? rem.referenceNumber : 'N/A'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Receipt Preview
                if (hasReceipt) ...[
                  Text(
                    'Bank Transfer / Deposit Receipt',
                    style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => _openReceiptViewerModal(context, rem.depositReceiptUrl!, riderName),
                    child: Container(
                      height: 180,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.black12,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Image.network(
                            rem.depositReceiptUrl!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            errorBuilder: (_, __, ___) => const Center(
                              child: Icon(Icons.broken_image_rounded, size: 40, color: Colors.grey),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.zoom_in, color: Colors.white, size: 16),
                                SizedBox(width: 4),
                                Text('Tap to Enlarge', style: TextStyle(color: Colors.white, fontSize: 11)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Confirmation Note
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00522A).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF00522A).withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, color: Color(0xFF00522A), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Before approving, confirm that you have verified the credit alert in the DC bank app or received physical cash.',
                          style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF00522A), height: 1.35),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Approve Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00522A),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.check_circle_rounded, size: 18),
                    label: Text(
                      'Approve & Clear Balance (${CurrencyFormatter.formatNaira(rem.amount)})',
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      try {
                        final res = await ref.read(dcConsoleProvider.notifier).approveCashRemittance(rem.id);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: const Color(0xFF16A34A),
                              content: Text(res['message']?.toString() ?? 'Remittance cleared successfully!'),
                            ),
                          );
                          _loadData();
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(backgroundColor: const Color(0xFFDC2626), content: Text('Error approving remittance: $e')),
                          );
                        }
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openReceiptViewerModal(BuildContext context, String url, String riderName) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Container(
                    padding: const EdgeInsets.all(24),
                    color: Colors.white,
                    child: const Text('Could not load image.'),
                  ),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value, {bool isBold = false, Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 12.5,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
