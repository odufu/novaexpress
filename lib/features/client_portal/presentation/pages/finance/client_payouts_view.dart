import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:novexps/core/theme/theme_provider.dart';
import 'package:novexps/features/client_portal/domain/entities/client_closer.dart';
import 'package:novexps/features/client_portal/domain/entities/client_marketer.dart';
import 'package:novexps/features/client_portal/presentation/providers/client_portal_provider.dart';
import 'package:novexps/features/client_portal/presentation/widgets/client_disburse_closer_payout_modal.dart';
import 'package:novexps/features/client_portal/presentation/widgets/client_disburse_marketer_payout_modal.dart';

class ClientPayoutsView extends ConsumerStatefulWidget {
  const ClientPayoutsView({super.key});

  @override
  ConsumerState<ClientPayoutsView> createState() => _ClientPayoutsViewState();
}

class _ClientPayoutsViewState extends ConsumerState<ClientPayoutsView> {
  final TextEditingController _searchController = TextEditingController();

  String _selectedRole = 'all'; // 'all', 'closer', 'marketer'
  String _selectedStatus = 'all'; // 'all', 'unpaid', 'settled'
  String _searchQuery = '';

  final currencyFormat = NumberFormat('#,##0.00', 'en_US');
  final dateFormat = DateFormat('dd MMM yyyy');

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      if (_searchQuery != _searchController.text) {
        setState(() => _searchQuery = _searchController.text);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<_AgentPayoutData> _getFilteredAgents(List<ClientCloser> closers, List<ClientMarketer> marketers) {
    final List<_AgentPayoutData> list = [];

    if (_selectedRole == 'all' || _selectedRole == 'closer') {
      for (final c in closers) {
        final totalEarned = c.totalPaidCommission + c.unpaidCommissionBalance;
        list.add(_AgentPayoutData(
          id: c.id,
          name: c.fullName,
          code: c.closerCode,
          phone: c.phone,
          isCloser: true,
          commissionModel: '₦${c.commissionRate.toStringAsFixed(0)} / delivered',
          deliveredCount: c.totalOrdersDelivered,
          totalEarned: totalEarned,
          paidAmount: c.totalPaidCommission,
          unpaidBalance: c.unpaidCommissionBalance,
          bankName: c.bankName,
          accountNumber: c.accountNumber,
          accountName: c.accountName,
          originalCloser: c,
        ));
      }
    }

    if (_selectedRole == 'all' || _selectedRole == 'marketer') {
      for (final m in marketers) {
        final totalEarned = m.totalPaidCommission + m.unpaidCommissionBalance;
        list.add(_AgentPayoutData(
          id: m.id,
          name: m.fullName,
          code: m.marketerCode,
          phone: m.phone,
          isCloser: false,
          commissionModel: m.commissionModel == 'per_delivered_order'
              ? '₦${m.commissionPerDeliveredOrder.toStringAsFixed(0)} / delivered'
              : '₦${m.commissionPerFormSubmission.toStringAsFixed(0)} / lead',
          deliveredCount: m.totalOrdersDelivered,
          totalEarned: totalEarned,
          paidAmount: m.totalPaidCommission,
          unpaidBalance: m.unpaidCommissionBalance,
          bankName: m.bankName,
          accountNumber: m.accountNumber,
          accountName: m.accountName,
          originalMarketer: m,
        ));
      }
    }

    return list.where((item) {
      // Status filter
      if (_selectedStatus == 'unpaid' && item.unpaidBalance <= 0) return false;
      if (_selectedStatus == 'settled' && item.unpaidBalance > 0) return false;

      // Search query
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase().trim();
        final matchName = item.name.toLowerCase().contains(q);
        final matchCode = item.code.toLowerCase().contains(q);
        final matchPhone = item.phone.toLowerCase().contains(q);
        final matchBank = item.bankName.toLowerCase().contains(q);
        if (!matchName && !matchCode && !matchPhone && !matchBank) return false;
      }

      return true;
    }).toList();
  }

  void _disburseAgent(BuildContext context, _AgentPayoutData agent) {
    if (agent.isCloser && agent.originalCloser != null) {
      ClientDisburseCloserPayoutModal.show(context, closer: agent.originalCloser!);
    } else if (!agent.isCloser && agent.originalMarketer != null) {
      ClientDisburseMarketerPayoutModal.show(context, marketer: agent.originalMarketer!);
    }
  }

  void _showAgentDetailSheet(BuildContext context, _AgentPayoutData agent, bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              agent.name,
                              style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${agent.code} • ${agent.phone}',
                              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: (agent.isCloser ? const Color(0xFF0D9488) : const Color(0xFF8B5CF6)).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          agent.isCloser ? 'Telesales Closer' : 'Digital Marketer',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: agent.isCloser ? const Color(0xFF0D9488) : const Color(0xFF8B5CF6),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Unpaid Balance Highlight Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: agent.unpaidBalance > 0
                          ? const Color(0xFFF59E0B).withValues(alpha: 0.08)
                          : const Color(0xFF10B981).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: agent.unpaidBalance > 0
                            ? const Color(0xFFF59E0B).withValues(alpha: 0.25)
                            : const Color(0xFF10B981).withValues(alpha: 0.25),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              agent.unpaidBalance > 0 ? 'Unpaid Balance Due' : 'All Commissions Settled',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: agent.unpaidBalance > 0 ? const Color(0xFFD97706) : const Color(0xFF059669),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '₦${currencyFormat.format(agent.unpaidBalance)}',
                              style: GoogleFonts.inter(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: agent.unpaidBalance > 0 ? const Color(0xFFD97706) : const Color(0xFF10B981),
                              ),
                            ),
                          ],
                        ),
                        Icon(
                          agent.unpaidBalance > 0 ? Icons.pending_actions_rounded : Icons.check_circle_rounded,
                          color: agent.unpaidBalance > 0 ? const Color(0xFFD97706) : const Color(0xFF10B981),
                          size: 30,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                  Text('Earnings & Performance', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),

                  _buildSheetDetailRow('Commission Rate', agent.commissionModel, isDark),
                  _buildSheetDetailRow('Delivered Conversions', '${agent.deliveredCount} orders', isDark),
                  _buildSheetDetailRow('Cumulative Commission Earned', '₦${currencyFormat.format(agent.totalEarned)}', isDark),
                  _buildSheetDetailRow('Total Disbursed to Date', '₦${currencyFormat.format(agent.paidAmount)}', isDark),

                  const Divider(height: 24),
                  Text('Disbursement Bank Account', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),

                  _buildSheetDetailRow('Bank Name', agent.bankName.isNotEmpty ? agent.bankName : 'Not Set', isDark),
                  _buildSheetDetailRow('Account Number', agent.accountNumber.isNotEmpty ? agent.accountNumber : 'Not Set', isDark),
                  if (agent.accountName.isNotEmpty)
                    _buildSheetDetailRow('Account Name', agent.accountName, isDark),

                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () => Navigator.pop(ctx),
                          child: Text('Close', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0D9488),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            elevation: 0,
                          ),
                          onPressed: () {
                            Navigator.pop(ctx);
                            _disburseAgent(context, agent);
                          },
                          icon: const Icon(Icons.send_rounded, size: 16),
                          label: Text('Disburse Payout', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSheetDetailRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
          ),
          Text(
            value,
            style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF0F172A)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(clientPortalProvider);
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == ThemeMode.dark ||
        (themeMode == ThemeMode.system &&
            MediaQuery.of(context).platformBrightness == Brightness.dark);
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;

    final filteredAgents = _getFilteredAgents(state.closers, state.marketers);

    // DYNAMIC FILTER RECALCULATION
    double totalEarned = 0;
    double totalPaid = 0;
    double totalUnpaid = 0;
    int activeAgentsCount = filteredAgents.length;

    for (final a in filteredAgents) {
      totalEarned += a.totalEarned;
      totalPaid += a.paidAmount;
      totalUnpaid += a.unpaidBalance;
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: isMobile && filteredAgents.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: () {
                final dueAgents = filteredAgents.where((a) => a.unpaidBalance > 0).toList();
                if (dueAgents.isNotEmpty) {
                  _disburseAgent(context, dueAgents.first);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('All agents are currently settled up!')),
                  );
                }
              },
              backgroundColor: const Color(0xFF0D9488),
              icon: const Icon(Icons.send_rounded, color: Colors.white),
              label: Text('Disburse', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white)),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () => ref.read(clientPortalProvider.notifier).loadClientData(),
        child: ListView(
          padding: EdgeInsets.symmetric(horizontal: isMobile ? 14 : 24, vertical: 18),
          children: [
            // 1. OPEN METRIC STRIP (Dynamically recalculates on filter changes)
            _buildOpenMetricStrip(
              totalEarned: totalEarned,
              totalPaid: totalPaid,
              totalUnpaid: totalUnpaid,
              activeCount: activeAgentsCount,
              isDark: isDark,
              isMobile: isMobile,
            ),
            const SizedBox(height: 20),

            // 2. INTEGRATED FILTER TOOLBAR WITH ACTION BUTTON ON FAR RIGHT
            _buildIntegratedFilterBar(context, filteredAgents, isDark, isMobile),
            const SizedBox(height: 18),

            // 3. DATA PRESENTATION: DESKTOP TABLE vs MOBILE CONDENSED CARDS
            if (filteredAgents.isEmpty)
              _buildEmptyState(isDark)
            else if (isMobile)
              _buildMobileCardsList(context, filteredAgents, isDark)
            else
              _buildDesktopTable(context, filteredAgents, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildOpenMetricStrip({
    required double totalEarned,
    required double totalPaid,
    required double totalUnpaid,
    required int activeCount,
    required bool isDark,
    required bool isMobile,
  }) {
    final metrics = [
      (
        label: 'Total Earned',
        value: '₦${currencyFormat.format(totalEarned)}',
        subtext: 'Cumulative commissions',
        icon: Icons.monetization_on_rounded,
        color: const Color(0xFF3B82F6),
      ),
      (
        label: 'Settled & Disbursed',
        value: '₦${currencyFormat.format(totalPaid)}',
        subtext: 'Paid into bank accounts',
        icon: Icons.check_circle_rounded,
        color: const Color(0xFF10B981),
      ),
      (
        label: 'Unpaid Due Balance',
        value: '₦${currencyFormat.format(totalUnpaid)}',
        subtext: 'Pending disbursement',
        icon: Icons.pending_actions_rounded,
        color: const Color(0xFFF59E0B),
      ),
      (
        label: 'Active Agents',
        value: '$activeCount',
        subtext: 'Closers & marketers',
        icon: Icons.people_alt_rounded,
        color: const Color(0xFF8B5CF6),
      ),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: isMobile
          ? Column(
              children: [
                Row(
                  children: [
                    Expanded(child: _buildMetricItem(metrics[0], isDark)),
                    Container(height: 50, width: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    Expanded(child: _buildMetricItem(metrics[1], isDark)),
                  ],
                ),
                const SizedBox(height: 14),
                Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(child: _buildMetricItem(metrics[2], isDark)),
                    Container(height: 50, width: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    Expanded(child: _buildMetricItem(metrics[3], isDark)),
                  ],
                ),
              ],
            )
          : Row(
              children: [
                Expanded(child: _buildMetricItem(metrics[0], isDark)),
                Container(height: 55, width: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                Expanded(child: _buildMetricItem(metrics[1], isDark)),
                Container(height: 55, width: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                Expanded(child: _buildMetricItem(metrics[2], isDark)),
                Container(height: 55, width: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                Expanded(child: _buildMetricItem(metrics[3], isDark)),
              ],
            ),
    );
  }

  Widget _buildMetricItem(
    ({String label, String value, String subtext, IconData icon, Color color}) item,
    bool isDark,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(item.icon, size: 14, color: item.color),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  item.label,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            item.value,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
              letterSpacing: -0.3,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            item.subtext,
            style: GoogleFonts.inter(
              fontSize: 10,
              color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildIntegratedFilterBar(
    BuildContext context,
    List<_AgentPayoutData> agents,
    bool isDark,
    bool isMobile,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: isMobile
          ? Column(
              children: [
                _buildSearchField(isDark),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: _buildRoleDropdown(isDark)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildStatusDropdown(isDark)),
                  ],
                ),
              ],
            )
          : Row(
              children: [
                Expanded(
                  flex: 2,
                  child: _buildSearchField(isDark),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 160,
                  child: _buildRoleDropdown(isDark),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 150,
                  child: _buildStatusDropdown(isDark),
                ),
                const SizedBox(width: 12),
                // Action button on far right
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D9488),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  onPressed: () {
                    final dueAgents = agents.where((a) => a.unpaidBalance > 0).toList();
                    if (dueAgents.isNotEmpty) {
                      _disburseAgent(context, dueAgents.first);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('All agents are currently settled up!')),
                      );
                    }
                  },
                  icon: const Icon(Icons.send_rounded, size: 16),
                  label: Text('Disburse Payout', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
    );
  }

  Widget _buildSearchField(bool isDark) {
    return TextField(
      controller: _searchController,
      style: GoogleFonts.inter(fontSize: 12.5),
      decoration: InputDecoration(
        hintText: 'Search agent name, code, phone...',
        hintStyle: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
        prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Colors.grey),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear_rounded, size: 16),
                onPressed: () => _searchController.clear(),
              )
            : null,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        filled: true,
        fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        ),
      ),
    );
  }

  Widget _buildRoleDropdown(bool isDark) {
    return DropdownButtonFormField<String>(
      value: _selectedRole,
      isExpanded: true,
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        filled: true,
        fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        ),
      ),
      items: const [
        DropdownMenuItem(value: 'all', child: Text('All Roles', style: TextStyle(fontSize: 12))),
        DropdownMenuItem(value: 'closer', child: Text('Telesales Closers', style: TextStyle(fontSize: 12))),
        DropdownMenuItem(value: 'marketer', child: Text('Digital Marketers', style: TextStyle(fontSize: 12))),
      ],
      onChanged: (val) {
        if (val != null) setState(() => _selectedRole = val);
      },
    );
  }

  Widget _buildStatusDropdown(bool isDark) {
    return DropdownButtonFormField<String>(
      value: _selectedStatus,
      isExpanded: true,
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        filled: true,
        fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        ),
      ),
      items: const [
        DropdownMenuItem(value: 'all', child: Text('All Statuses', style: TextStyle(fontSize: 12))),
        DropdownMenuItem(value: 'unpaid', child: Text('Unpaid Due', style: TextStyle(fontSize: 12))),
        DropdownMenuItem(value: 'settled', child: Text('Fully Settled', style: TextStyle(fontSize: 12))),
      ],
      onChanged: (val) {
        if (val != null) setState(() => _selectedStatus = val);
      },
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.people_outline_rounded, size: 48, color: Color(0xFF94A3B8)),
            const SizedBox(height: 12),
            Text(
              'No Agents Found',
              style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Try adjusting your role or search filters.',
              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileCardsList(
    BuildContext context,
    List<_AgentPayoutData> list,
    bool isDark,
  ) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, idx) {
        final agent = list[idx];
        final hasDue = agent.unpaidBalance > 0;

        return Material(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: () => _showAgentDetailSheet(context, agent, isDark),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Line 1: Agent Name + Closer Code + Role Badge
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(agent.name, style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 6),
                          Text('(${agent.code})', style: GoogleFonts.inter(fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: (agent.isCloser ? const Color(0xFF0D9488) : const Color(0xFF8B5CF6)).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          agent.isCloser ? 'Closer' : 'Marketer',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: agent.isCloser ? const Color(0xFF0D9488) : const Color(0xFF8B5CF6),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Line 2: Delivered Orders + Bank details
                  Row(
                    children: [
                      Text(
                        '${agent.deliveredCount} delivered',
                        style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
                      ),
                      Text(' • ', style: GoogleFonts.inter(color: Colors.grey)),
                      Flexible(
                        child: Text(
                          agent.bankName.isNotEmpty ? agent.bankName : 'No Bank Set',
                          style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Line 3: Unpaid Balance (or Paid) + Quick Disburse Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(hasDue ? 'Unpaid Balance' : 'Fully Settled', style: GoogleFonts.inter(fontSize: 10, color: Colors.grey)),
                          Text(
                            '₦${currencyFormat.format(agent.unpaidBalance)}',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: hasDue ? const Color(0xFFD97706) : const Color(0xFF10B981),
                            ),
                          ),
                        ],
                      ),
                      if (hasDue)
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0D9488),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            elevation: 0,
                          ),
                          onPressed: () => _disburseAgent(context, agent),
                          child: Text('Disburse', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold)),
                        )
                      else
                        const Icon(Icons.chevron_right_rounded, size: 18, color: Colors.grey),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDesktopTable(
    BuildContext context,
    List<_AgentPayoutData> list,
    bool isDark,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        children: [
          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
              border: Border(
                bottom: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
            ),
            child: Row(
              children: [
                Expanded(flex: 3, child: Text('AGENT NAME & CODE', style: _tableHeaderStyle())),
                Expanded(flex: 2, child: Text('ROLE', style: _tableHeaderStyle())),
                Expanded(flex: 1, child: Text('DELIVERIES', style: _tableHeaderStyle())),
                Expanded(flex: 2, child: Text('COMMISSION RATE', style: _tableHeaderStyle())),
                Expanded(flex: 2, child: Text('TOTAL EARNED', style: _tableHeaderStyle())),
                Expanded(flex: 2, child: Text('PAID TO DATE', style: _tableHeaderStyle())),
                Expanded(flex: 2, child: Text('UNPAID DUE', style: _tableHeaderStyle())),
                SizedBox(width: 100, child: Text('ACTIONS', style: _tableHeaderStyle(), textAlign: TextAlign.right)),
              ],
            ),
          ),

          // Table Rows
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: list.length,
            separatorBuilder: (_, __) => Divider(
              height: 1,
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            ),
            itemBuilder: (context, idx) {
              final agent = list[idx];
              final hasDue = agent.unpaidBalance > 0;

              return InkWell(
                onTap: () => _showAgentDetailSheet(context, agent, isDark),
                hoverColor: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      // Agent Name & Code
                      Expanded(
                        flex: 3,
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: (agent.isCloser ? const Color(0xFF0D9488) : const Color(0xFF8B5CF6)).withValues(alpha: 0.15),
                              child: Text(
                                agent.name.isNotEmpty ? agent.name[0].toUpperCase() : '?',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: agent.isCloser ? const Color(0xFF0D9488) : const Color(0xFF8B5CF6),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    agent.name,
                                    style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    agent.code,
                                    style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Role
                      Expanded(
                        flex: 2,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: (agent.isCloser ? const Color(0xFF0D9488) : const Color(0xFF8B5CF6)).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              agent.isCloser ? 'Closer' : 'Marketer',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: agent.isCloser ? const Color(0xFF0D9488) : const Color(0xFF8B5CF6),
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Deliveries
                      Expanded(
                        flex: 1,
                        child: Text(
                          '${agent.deliveredCount}',
                          style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600),
                        ),
                      ),
                      // Commission Rate
                      Expanded(
                        flex: 2,
                        child: Text(
                          agent.commissionModel,
                          style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                        ),
                      ),
                      // Total Earned
                      Expanded(
                        flex: 2,
                        child: Text(
                          '₦${currencyFormat.format(agent.totalEarned)}',
                          style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600),
                        ),
                      ),
                      // Paid to Date
                      Expanded(
                        flex: 2,
                        child: Text(
                          '₦${currencyFormat.format(agent.paidAmount)}',
                          style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: const Color(0xFF10B981)),
                        ),
                      ),
                      // Unpaid Due
                      Expanded(
                        flex: 2,
                        child: Text(
                          '₦${currencyFormat.format(agent.unpaidBalance)}',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: hasDue ? const Color(0xFFD97706) : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                      // Ghost Actions
                      SizedBox(
                        width: 100,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (hasDue)
                              TextButton(
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  visualDensity: VisualDensity.compact,
                                ),
                                onPressed: () => _disburseAgent(context, agent),
                                child: Text('Disburse', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF0D9488))),
                              )
                            else
                              IconButton(
                                icon: const Icon(Icons.remove_red_eye_outlined, size: 16),
                                tooltip: 'View Agent',
                                onPressed: () => _showAgentDetailSheet(context, agent, isDark),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  TextStyle _tableHeaderStyle() {
    return GoogleFonts.inter(
      fontSize: 10,
      fontWeight: FontWeight.w700,
      color: const Color(0xFF64748B),
      letterSpacing: 0.5,
    );
  }
}

class _AgentPayoutData {
  final String id;
  final String name;
  final String code;
  final String phone;
  final bool isCloser;
  final String commissionModel;
  final int deliveredCount;
  final double totalEarned;
  final double paidAmount;
  final double unpaidBalance;
  final String bankName;
  final String accountNumber;
  final String accountName;
  final ClientCloser? originalCloser;
  final ClientMarketer? originalMarketer;

  _AgentPayoutData({
    required this.id,
    required this.name,
    required this.code,
    required this.phone,
    required this.isCloser,
    required this.commissionModel,
    required this.deliveredCount,
    required this.totalEarned,
    required this.paidAmount,
    required this.unpaidBalance,
    required this.bankName,
    required this.accountNumber,
    required this.accountName,
    this.originalCloser,
    this.originalMarketer,
  });
}
