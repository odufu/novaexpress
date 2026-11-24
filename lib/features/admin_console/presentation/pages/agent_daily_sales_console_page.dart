import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../core/helpers/formatters.dart';
import '../../../../core/helpers/uuid_helper.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/nova_critical_action_confirmation_modal.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/admin_models.dart';
import '../../domain/entities/agent_daily_sale_record.dart';
import '../providers/admin_console_provider.dart';

class AgentDailySalesConsolePage extends ConsumerStatefulWidget {
  const AgentDailySalesConsolePage({super.key});

  @override
  ConsumerState<AgentDailySalesConsolePage> createState() =>
      _AgentDailySalesConsolePageState();
}

class _AgentDailySalesConsolePageState
    extends ConsumerState<AgentDailySalesConsolePage> {
  int _currentViewIndex = 0; // 0: Sales Feed, 1: Agent Stock Custody, 2: DC Shelves & Velocity
  String _agentFilter = 'all';
  String _selectedMerchantFilter = 'all';
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final state = ref.watch(adminConsoleProvider);
    final notifier = ref.read(adminConsoleProvider.notifier);
    final currentUser = ref.watch(authProvider).user;
    final operatorName = currentUser?.fullName.isNotEmpty == true
        ? currentUser!.fullName
        : 'Damilare Ajani';

    // 1. Filter Sales by Agent, Merchant, and Search
    final allSales = state.dailySales;
    final filteredSales = allSales.where((s) {
      if (_agentFilter != 'all' && s.agentId != _agentFilter && s.agentCode != _agentFilter) {
        return false;
      }
      if (_selectedMerchantFilter != 'all') {
        final mFilter = _selectedMerchantFilter.toLowerCase();
        final matchesId = s.merchantId != null && s.merchantId!.toLowerCase() == mFilter;
        final matchesName = s.merchantName != null && s.merchantName!.toLowerCase().contains(mFilter);
        final isNovacare = mFilter.contains('nova');
        if (!matchesId && !matchesName && !isNovacare) {
          return false;
        }
      }
      final q = _searchCtrl.text.trim().toLowerCase();
      if (q.isNotEmpty) {
        return s.agentName.toLowerCase().contains(q) ||
            s.customerName.toLowerCase().contains(q) ||
            s.orderReference.toLowerCase().contains(q) ||
            s.items.any((i) => i.productName.toLowerCase().contains(q));
      }
      return true;
    }).toList();

    // 2. Filter Agents by Selected Merchant and Search
    final displayedAgents = state.agents.where((a) {
      if (_agentFilter != 'all' && a.id != _agentFilter && a.agentCode != _agentFilter) {
        return false;
      }
      if (_selectedMerchantFilter != 'all') {
        final mFilter = _selectedMerchantFilter.toLowerCase();
        final isNovacare = mFilter.contains('nova');
        final assignedMatch = a.assignedMerchantIds.any((id) => id.toLowerCase() == mFilter) ||
            a.assignedMerchantNames.any((name) => name.toLowerCase().contains(mFilter));
        final hasStock = a.heldStock.values.any((q) => q > 0);
        // Novacare has all 94 agents across the nation
        if (!assignedMatch && !hasStock && !isNovacare) {
          return false;
        }
      }
      final q = _searchCtrl.text.trim().toLowerCase();
      if (q.isNotEmpty) {
        return a.name.toLowerCase().contains(q) ||
            a.agentCode.toLowerCase().contains(q) ||
            a.coverageStates.any((s) => s.toLowerCase().contains(q));
      }
      return true;
    }).toList();

    // 3. Filter Catalog by Selected Merchant
    final displayedCatalog = state.globalStock.where((p) {
      if (_selectedMerchantFilter != 'all') {
        final mFilter = _selectedMerchantFilter.toLowerCase();
        final matchesId = p.merchantId.toLowerCase() == mFilter;
        final matchesName = p.merchantName.toLowerCase().contains(mFilter);
        final isNovacare = mFilter.contains('nova');
        if (!matchesId && !matchesName && !isNovacare) {
          return false;
        }
      }
      final q = _searchCtrl.text.trim().toLowerCase();
      if (q.isNotEmpty) {
        return p.productName.toLowerCase().contains(q) || p.sku.toLowerCase().contains(q);
      }
      return true;
    }).toList();

    // Metrics for Selected Scope
    final totalUnitsSold = filteredSales.fold<int>(0, (sum, s) => sum + s.totalUnits);
    final totalCodIngested = filteredSales.fold<double>(0.0, (sum, s) => sum + s.totalAmount);
    final activeAgentsCount = filteredSales.map((s) => s.agentCode).toSet().length;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B1120) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0.5,
        backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
          },
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Master Daily Sales & Stock Ops Console',
              style: GoogleFonts.inter(fontSize: 15.5, fontWeight: FontWeight.bold),
            ),
            Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: Color(0xFF10B981),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  'Operator: $operatorName • Multi-Merchant Controller',
                  style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Network State',
            onPressed: () => notifier.loadAll(),
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Merchant Selection & Scope Control Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : Colors.white,
              border: Border(
                bottom: BorderSide(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: AppColors.orange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.storefront_rounded, color: AppColors.orange, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ACTIVE MERCHANT PORTFOLIO',
                        style: GoogleFonts.inter(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF64748B),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedMerchantFilter,
                          isDense: true,
                          dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                          style: GoogleFonts.inter(
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: 'all',
                              child: Text('🌐 All Merchants (Universal Stock & Logistics)'),
                            ),
                            const DropdownMenuItem(
                              value: '00000000-0000-4000-8000-791731264594',
                              child: Text('🌿 Novacare Limited (9 Products • 94 Agents)'),
                            ),
                            const DropdownMenuItem(
                              value: 'shop-eleven-ltd',
                              child: Text('🛍️ Shop Eleven Limited'),
                            ),
                            const DropdownMenuItem(
                              value: 'leafora-direct',
                              child: Text('✨ Leafora Direct Essence'),
                            ),
                            ...state.merchants
                                .where((m) =>
                                    m.id != '00000000-0000-4000-8000-791731264594' &&
                                    !m.businessName.toLowerCase().contains('novacare'))
                                .map((m) {
                              return DropdownMenuItem(
                                value: m.id,
                                child: Text('🏢 ${m.businessName}'),
                              );
                            }),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _selectedMerchantFilter = val;
                                _agentFilter = 'all';
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0284C7).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${displayedCatalog.length} Products • ${displayedAgents.length} Agents',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0284C7),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 2. KPI Ribbon (Live metrics for selected scope)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0B1120) : const Color(0xFFF1F5F9),
              border: Border(
                bottom: BorderSide(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                ),
              ),
            ),
            child: Row(
              children: [
                _buildKpiChip(
                  isDark: isDark,
                  label: 'Sales Today',
                  value: '${filteredSales.length}',
                  sub: '$totalUnitsSold units deducted',
                  color: const Color(0xFF3B82F6),
                  icon: Icons.point_of_sale_rounded,
                ),
                const SizedBox(width: 8),
                _buildKpiChip(
                  isDark: isDark,
                  label: 'COD Ingested',
                  value: CurrencyFormatter.formatNaira(totalCodIngested),
                  sub: 'auto reconciled',
                  color: const Color(0xFF10B981),
                  icon: Icons.account_balance_wallet_rounded,
                ),
                const SizedBox(width: 8),
                _buildKpiChip(
                  isDark: isDark,
                  label: 'Active Agents',
                  value: '$activeAgentsCount',
                  sub: 'of ${displayedAgents.length} assigned',
                  color: AppColors.orange,
                  icon: Icons.local_shipping_rounded,
                ),
              ],
            ),
          ),

          // 3. Tab Navigation Selector (3 Core Operational Views)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.all(3),
            child: Row(
              children: [
                _buildTabButton(
                  index: 0,
                  label: "Sales Log (${filteredSales.length})",
                  icon: Icons.receipt_long_rounded,
                  isDark: isDark,
                ),
                _buildTabButton(
                  index: 1,
                  label: "Agent Custody (${displayedAgents.length})",
                  icon: Icons.inventory_2_rounded,
                  isDark: isDark,
                ),
                _buildTabButton(
                  index: 2,
                  label: "DC Shelves (${displayedCatalog.length})",
                  icon: Icons.warehouse_rounded,
                  isDark: isDark,
                ),
              ],
            ),
          ),

          // 4. Search & Filter Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 38,
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (_) => setState(() {}),
                      style: GoogleFonts.inter(fontSize: 12),
                      decoration: InputDecoration(
                        hintText: _currentViewIndex == 0
                            ? 'Search sales by agent, order #, customer...'
                            : (_currentViewIndex == 1
                                ? 'Search agent name, code, state...'
                                : 'Search products, SKU, category...'),
                        prefixIcon: const Icon(Icons.search_rounded, size: 18),
                        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (_currentViewIndex != 2) ...[
                  const SizedBox(width: 8),
                  Container(
                    height: 38,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _agentFilter,
                        dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                        items: [
                          const DropdownMenuItem(value: 'all', child: Text('All Agents')),
                          ...displayedAgents.take(40).map((a) {
                            return DropdownMenuItem(
                              value: a.agentCode.isNotEmpty ? a.agentCode : a.id,
                              child: Text(
                                a.name.length > 20 ? '${a.name.substring(0, 18)}...' : a.name,
                              ),
                            );
                          }),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _agentFilter = val);
                        },
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 6),

          // 5. Main Body Content Switcher
          Expanded(
            child: _currentViewIndex == 0
                ? _buildSalesFeed(filteredSales, isDark)
                : (_currentViewIndex == 1
                    ? _buildAgentStockView(
                        displayedAgents,
                        displayedCatalog,
                        state,
                        notifier,
                        operatorName,
                        isDark,
                      )
                    : _buildDcShelvesView(displayedCatalog, state, isDark)),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.orange,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_shopping_cart_rounded, size: 20),
        label: Text(
          'Log Daily Sale & Balance Stock',
          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
        ),
        onPressed: () => _openLogSaleModal(
          context: context,
          state: state,
          notifier: notifier,
          operatorName: operatorName,
          isDark: isDark,
          initialMerchantFilter: _selectedMerchantFilter,
        ),
      ),
    );
  }

  Widget _buildTabButton({
    required int index,
    required String label,
    required IconData icon,
    required bool isDark,
  }) {
    final isSelected = _currentViewIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _currentViewIndex = index),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? const Color(0xFF0F172A) : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    )
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: isSelected ? AppColors.orange : const Color(0xFF64748B),
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected
                        ? (isDark ? Colors.white : const Color(0xFF0F172A))
                        : const Color(0xFF64748B),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKpiChip({
    required bool isDark,
    required String label,
    required String value,
    required String sub,
    required Color color,
    required IconData icon,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.12 : 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 13, color: color),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: const Color(0xFF64748B),
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              sub,
              style: GoogleFonts.inter(fontSize: 9.5, color: color, fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSalesFeed(List<AgentDailySaleRecord> sales, bool isDark) {
    if (sales.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long_outlined, size: 48, color: const Color(0xFF94A3B8).withValues(alpha: 0.6)),
            const SizedBox(height: 12),
            Text(
              'No daily sales recorded for this merchant filter',
              style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              'Tap "+ Log Daily Sale & Balance Stock" below to record completed orders.\nUnits will automatically subtract from agent custody.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
      itemCount: sales.length,
      itemBuilder: (context, idx) {
        final sale = sales[idx];
        return Card(
          elevation: 0.5,
          margin: const EdgeInsets.only(bottom: 10),
          color: isDark ? const Color(0xFF0F172A) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.local_shipping_rounded, size: 16, color: Color(0xFF2563EB)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            sale.agentName,
                            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Code: ${sale.agentCode} • ${DateFormat('hh:mm a').format(sale.timestamp)}${sale.merchantName != null ? " • ${sale.merchantName}" : ""}',
                            style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        CurrencyFormatter.formatNaira(sale.totalAmount),
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF059669),
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 16),
                Row(
                  children: [
                    const Icon(Icons.person_outline_rounded, size: 14, color: Color(0xFF64748B)),
                    const SizedBox(width: 4),
                    Text(
                      sale.customerName,
                      style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600),
                    ),
                    if (sale.customerPhone.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Text(
                        '(${sale.customerPhone})',
                        style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                      ),
                    ],
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '-${sale.totalUnits} units deducted',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFDC2626),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: sale.items.map((item) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${item.quantity}x ${item.productName}',
                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500),
                      ),
                    );
                  }).toList(),
                ),
                if (sale.orderReference.isNotEmpty || sale.loggedBy.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Ref: ${sale.orderReference.isNotEmpty ? sale.orderReference : "Direct Delivery"} • Operator: ${sale.loggedBy}',
                    style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF94A3B8)),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAgentStockView(
    List<AdminLogisticsAgent> agents,
    List<AdminGlobalStockItem> catalog,
    AdminConsoleState state,
    AdminConsoleNotifier notifier,
    String operatorName,
    bool isDark,
  ) {
    if (agents.isEmpty) {
      return Center(
        child: Text(
          'No agents found matching current search/merchant filter',
          style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B)),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
      itemCount: agents.length,
      itemBuilder: (context, idx) {
        final agent = agents[idx];
        final totalUnits = agent.heldStock.values.fold<int>(0, (s, q) => s + q);

        return Card(
          elevation: 0.5,
          margin: const EdgeInsets.only(bottom: 10),
          color: isDark ? const Color(0xFF0F172A) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
            ),
          ),
          child: ExpansionTile(
            shape: const Border(),
            leading: CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFFF97316).withValues(alpha: 0.15),
              child: const Icon(Icons.inventory_2_outlined, size: 18, color: AppColors.orange),
            ),
            title: Text(
              agent.name,
              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              'Code: ${agent.agentCode} • ${agent.assignedWarehouseName ?? "Abuja Central DC"} • ${agent.coverageStates.isNotEmpty ? agent.coverageStates.first : "National"}',
              style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF64748B)),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: totalUnits > 0
                        ? const Color(0xFF10B981).withValues(alpha: 0.12)
                        : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '$totalUnits units',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: totalUnits > 0 ? const Color(0xFF059669) : const Color(0xFF94A3B8),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  icon: const Icon(Icons.edit_note_rounded, size: 20, color: AppColors.orange),
                  tooltip: 'Manually Adjust Custody',
                  onPressed: () => _openManualCustodyEditDialog(
                    context: context,
                    agent: agent,
                    initialSku: null,
                    state: state,
                    notifier: notifier,
                    operatorName: operatorName,
                    isDark: isDark,
                  ),
                ),
              ],
            ),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(),
                    Row(
                      children: [
                        Text(
                          'Live Physical Custody by Product:',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                        const Spacer(),
                        InkWell(
                          onTap: () => _openManualCustodyEditDialog(
                            context: context,
                            agent: agent,
                            initialSku: null,
                            state: state,
                            notifier: notifier,
                            operatorName: operatorName,
                            isDark: isDark,
                          ),
                          child: Text(
                            '+ Edit / Balance Stock',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppColors.orange,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (agent.heldStock.isEmpty || totalUnits == 0)
                      Text(
                        'No physical stock currently held in custody.',
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontStyle: FontStyle.italic,
                          color: const Color(0xFF94A3B8),
                        ),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: agent.heldStock.entries.map((e) {
                          final pMatch = catalog.cast<AdminGlobalStockItem?>().firstWhere(
                                (p) => p?.sku == e.key || p?.productName == e.key,
                                orElse: () => null,
                              );
                          final label = pMatch?.productName ?? e.key;

                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  label,
                                  style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '${e.value}',
                                    style: GoogleFonts.jetBrainsMono(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF2563EB),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                InkWell(
                                  onTap: () => _openManualCustodyEditDialog(
                                    context: context,
                                    agent: agent,
                                    initialSku: e.key,
                                    state: state,
                                    notifier: notifier,
                                    operatorName: operatorName,
                                    isDark: isDark,
                                  ),
                                  child: const Icon(Icons.edit_outlined, size: 14, color: AppColors.orange),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDcShelvesView(
    List<AdminGlobalStockItem> catalog,
    AdminConsoleState state,
    bool isDark,
  ) {
    if (catalog.isEmpty) {
      return Center(
        child: Text(
          'No products found matching current merchant scope.',
          style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B)),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
      itemCount: catalog.length,
      itemBuilder: (context, idx) {
        final p = catalog[idx];
        final abujaStock = p.dcStockBreakdown['Abuja Central DC'] ?? 0;
        final lagosStock = p.dcStockBreakdown['Lagos Central DC'] ?? 0;
        final totalWh = abujaStock + lagosStock;

        // Total custody held by all agents for this product
        int totalFieldCustody = 0;
        for (final a in state.agents) {
          totalFieldCustody += (a.heldStock[p.sku] ?? a.heldStock[p.productName] ?? 0);
        }

        final combinedTotal = totalWh + totalFieldCustody;

        return Card(
          elevation: 0.5,
          margin: const EdgeInsets.only(bottom: 10),
          color: isDark ? const Color(0xFF0F172A) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.inventory_2_rounded, size: 18, color: Color(0xFF0284C7)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.productName,
                            style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'SKU: ${p.sku} • ${p.merchantName} • ${CurrencyFormatter.formatNaira(p.unitPrice)}',
                            style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '$combinedTotal total units',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF059669),
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 16),

                // DC Breakdown Cards
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('ABUJA CENTRAL DC',
                                style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.bold, color: const Color(0xFF64748B))),
                            const SizedBox(height: 2),
                            Text('$abujaStock units',
                                style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF0284C7))),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('LAGOS CENTRAL DC',
                                style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.bold, color: const Color(0xFF64748B))),
                            const SizedBox(height: 2),
                            Text('$lagosStock units',
                                style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF059669))),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('FIELD CUSTODY (94 AGENTS)',
                                style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.bold, color: const Color(0xFF64748B))),
                            const SizedBox(height: 2),
                            Text('$totalFieldCustody units',
                                style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.orange)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Open Manual Custody Adjustment Dialog with Strict Confirmation Modal
  void _openManualCustodyEditDialog({
    required BuildContext context,
    required AdminLogisticsAgent agent,
    required String? initialSku,
    required AdminConsoleState state,
    required AdminConsoleNotifier notifier,
    required String operatorName,
    required bool isDark,
  }) {
    String selectedSku = initialSku ??
        (agent.heldStock.keys.isNotEmpty
            ? agent.heldStock.keys.first
            : (state.globalStock.isNotEmpty ? state.globalStock.first.sku : ''));
    final currentQty = agent.heldStock[selectedSku] ?? 0;
    final qtyCtrl = TextEditingController(text: '$currentQty');
    final reasonCtrl = TextEditingController(text: 'Physical audit count balance reconciliation');

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final newQty = int.tryParse(qtyCtrl.text.trim()) ?? currentQty;
            final delta = newQty - currentQty;

            final pMatch = state.globalStock.cast<AdminGlobalStockItem?>().firstWhere(
                  (p) => p?.sku == selectedSku || p?.productName == selectedSku,
                  orElse: () => null,
                );
            final prodName = pMatch?.productName ?? selectedSku;

            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.orange.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.edit_note_rounded, color: AppColors.orange, size: 22),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Manual Custody Adjustment',
                            style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold)),
                        Text('Agent: ${agent.name} (${agent.agentCode})',
                            style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B))),
                      ],
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('PRODUCT SKU',
                        style: GoogleFonts.inter(
                            fontSize: 10.5, fontWeight: FontWeight.bold, color: const Color(0xFF64748B))),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: selectedSku.isNotEmpty ? selectedSku : null,
                      isExpanded: true,
                      decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
                      items: state.globalStock.map((p) {
                        final curHeld = agent.heldStock[p.sku] ?? agent.heldStock[p.productName] ?? 0;
                        return DropdownMenuItem(
                          value: p.sku,
                          child: Text('${p.productName} [${p.sku}] ($curHeld held)',
                              style: GoogleFonts.inter(fontSize: 12)),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() {
                            selectedSku = val;
                            final updatedCur = agent.heldStock[val] ?? 0;
                            qtyCtrl.text = '$updatedCur';
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 14),

                    // Current vs New Quantity
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('CURRENT CUSTODY',
                                    style: GoogleFonts.inter(
                                        fontSize: 9.5, color: const Color(0xFF64748B), fontWeight: FontWeight.bold)),
                                const SizedBox(height: 2),
                                Text('$currentQty units',
                                    style: GoogleFonts.jetBrainsMono(fontSize: 14, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: qtyCtrl,
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setDialogState(() {}),
                            decoration: const InputDecoration(
                              labelText: 'New Units *',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Delta indicator
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: delta == 0
                            ? const Color(0xFF64748B).withValues(alpha: 0.1)
                            : (delta > 0
                                ? const Color(0xFF10B981).withValues(alpha: 0.1)
                                : const Color(0xFFEF4444).withValues(alpha: 0.1)),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            delta == 0
                                ? Icons.info_outline
                                : (delta > 0 ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded),
                            size: 14,
                            color: delta == 0
                                ? const Color(0xFF64748B)
                                : (delta > 0 ? const Color(0xFF059669) : const Color(0xFFDC2626)),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            delta == 0
                                ? 'No change to custody balance'
                                : 'Adjustment Delta: ${delta > 0 ? "+$delta" : "$delta"} units',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: delta == 0
                                  ? const Color(0xFF64748B)
                                  : (delta > 0 ? const Color(0xFF059669) : const Color(0xFFDC2626)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    Text('ADJUSTMENT REASON / AUDIT NOTE *',
                        style: GoogleFonts.inter(
                            fontSize: 10.5, fontWeight: FontWeight.bold, color: const Color(0xFF64748B))),
                    const SizedBox(height: 4),
                    TextField(
                      controller: reasonCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        hintText: 'e.g. Physical count reconciliation, Waybill POD verification',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.security_update_good_rounded, size: 16),
                  label: const Text('Review & Apply Adjustment'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.orange,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    if (delta == 0) {
                      Navigator.pop(ctx);
                      return;
                    }

                    // Strict Confirmation Modal
                    final confirmed = await NovaCriticalActionConfirmationModal.show(
                      context: context,
                      title: 'Confirm Manual Custody Adjustment',
                      actionName: 'Adjust Stock for ${agent.name}',
                      promptMessage:
                          'You are about to manually adjust the physical stock custody for ${agent.name} on $prodName. This change will be permanently logged in the audit ledger.',
                      valuesets: {
                        'Target Agent': '${agent.name} (${agent.agentCode})',
                        'Product Item': prodName,
                        'Product SKU': selectedSku,
                        'Previous Custody': '$currentQty units',
                        'New Custody Balance': '$newQty units',
                        'Adjustment Delta': '${delta > 0 ? "+$delta" : "$delta"} units',
                        'Adjustment Reason': reasonCtrl.text.trim(),
                        'Authorizing Officer': operatorName,
                      },
                      operatorAccount: operatorName,
                      confirmLabel: 'Confirm & Apply Adjustment',
                      cancelLabel: 'Abort Adjustment',
                      brandColor: AppColors.orange,
                      isDestructive: delta < 0,
                    );

                    if (!confirmed) return;

                    final updatedHeldStock = Map<String, int>.from(agent.heldStock);
                    if (newQty > 0) {
                      updatedHeldStock[selectedSku] = newQty;
                    } else {
                      updatedHeldStock.remove(selectedSku);
                    }

                    await notifier.updateAgentCustodyStock(
                      agentId: agent.id,
                      newHeldStock: updatedHeldStock,
                      operatorName: operatorName,
                      reason: reasonCtrl.text.trim(),
                    );

                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: const Color(0xFF10B981),
                          content: Text(
                              'Custody adjusted successfully for ${agent.name}: $prodName = $newQty units.'),
                        ),
                      );
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Open Log Daily Sale & Balance Stock Modal
  void _openLogSaleModal({
    required BuildContext context,
    required AdminConsoleState state,
    required AdminConsoleNotifier notifier,
    required String operatorName,
    required bool isDark,
    required String initialMerchantFilter,
  }) {
    if (state.agents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No agents available to log sales for.')),
      );
      return;
    }

    String selectedMerchantId = initialMerchantFilter != 'all'
        ? initialMerchantFilter
        : '00000000-0000-4000-8000-791731264594'; // default to Novacare
    AdminLogisticsAgent selectedAgent = state.agents.first;

    // Movement Controllers
    final unitsSoldCtrl = TextEditingController(text: '0');
    final unitsReturnedCtrl = TextEditingController(text: '0');
    final dcRestockCtrl = TextEditingController(text: '0');
    String selectedDc = 'Abuja Central DC';

    final customerNameCtrl = TextEditingController();
    final customerPhoneCtrl = TextEditingController();
    final orderRefCtrl = TextEditingController(
        text: 'NX-ORD-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}');
    final deliveryLocCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    String paymentMethod = 'cash_cod';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        String? selectedProductSku = state.globalStock.isNotEmpty ? state.globalStock.first.sku : null;

        return StatefulBuilder(
          builder: (context, setModalState) {
            // Products available for this merchant
            final merchantProducts = state.globalStock.where((p) {
              if (selectedMerchantId == 'all') return true;
              return p.merchantId.toLowerCase() == selectedMerchantId.toLowerCase() ||
                  p.merchantName.toLowerCase().contains('novacare');
            }).toList();

            final activeCatalog = merchantProducts.isNotEmpty ? merchantProducts : state.globalStock;
            if (selectedProductSku == null || !activeCatalog.any((p) => p.sku == selectedProductSku)) {
              selectedProductSku = activeCatalog.isNotEmpty ? activeCatalog.first.sku : null;
            }

            final chosenProduct = activeCatalog.cast<AdminGlobalStockItem?>().firstWhere(
                  (p) => p?.sku == selectedProductSku,
                  orElse: () => activeCatalog.isNotEmpty ? activeCatalog.first : null,
                );

            final initialCustody = chosenProduct != null
                ? (selectedAgent.heldStock[chosenProduct.sku] ??
                    selectedAgent.heldStock[chosenProduct.productName] ??
                    0)
                : 0;

            final int soldUnits = int.tryParse(unitsSoldCtrl.text.trim()) ?? 0;
            final int returnedUnits = int.tryParse(unitsReturnedCtrl.text.trim()) ?? 0;
            final int dcReplenish = int.tryParse(dcRestockCtrl.text.trim()) ?? 0;

            final balancedClosing = (initialCustody + dcReplenish - soldUnits - returnedUnits) > 0
                ? (initialCustody + dcReplenish - soldUnits - returnedUnits)
                : 0;

            final unitPrice = chosenProduct?.unitPrice ?? 22800.0;
            final totalAmount = soldUnits * unitPrice;

            final currentDcShelfStock = chosenProduct?.dcStockBreakdown[selectedDc] ?? 0;

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle Bar
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFCBD5E1),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.orange.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.point_of_sale_rounded, color: AppColors.orange, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Log Daily Sales & Stock Depletion',
                                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                'Deducts delivered units from agent custody & syncs DC shelves',
                                style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const Divider(height: 20),

                    // 1. Merchant & Agent Selection
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('1. MERCHANT ACCOUNT',
                                  style: GoogleFonts.inter(
                                      fontSize: 10.5, fontWeight: FontWeight.bold, color: const Color(0xFF64748B))),
                              const SizedBox(height: 4),
                              DropdownButtonFormField<String>(
                                value: selectedMerchantId,
                                isExpanded: true,
                                decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
                                items: const [
                                  DropdownMenuItem(
                                      value: '00000000-0000-4000-8000-791731264594', child: Text('Novacare Limited')),
                                  DropdownMenuItem(value: 'shop-eleven-ltd', child: Text('Shop Eleven Limited')),
                                  DropdownMenuItem(value: 'leafora-direct', child: Text('Leafora Direct')),
                                  DropdownMenuItem(value: 'all', child: Text('All Merchants')),
                                ],
                                onChanged: (val) {
                                  if (val != null) {
                                    setModalState(() {
                                      selectedMerchantId = val;
                                    });
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('2. SELLING LOGISTICS AGENT',
                                  style: GoogleFonts.inter(
                                      fontSize: 10.5, fontWeight: FontWeight.bold, color: const Color(0xFF64748B))),
                              const SizedBox(height: 4),
                              DropdownButtonFormField<AdminLogisticsAgent>(
                                value: selectedAgent,
                                isExpanded: true,
                                decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
                                items: state.agents.map((a) {
                                  return DropdownMenuItem(
                                    value: a,
                                    child: Text(
                                      '${a.name} (${a.agentCode})',
                                      style: GoogleFonts.inter(fontSize: 12),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                }).toList(),
                                onChanged: (newAgent) {
                                  if (newAgent != null) {
                                    setModalState(() => selectedAgent = newAgent);
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // 2. Select Product SKU
                    Text('3. SELECT PRODUCT ITEM & SKU',
                        style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.bold, color: const Color(0xFF64748B))),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<String>(
                      value: selectedProductSku,
                      isExpanded: true,
                      decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
                      items: activeCatalog.map((p) {
                        final curCustody = selectedAgent.heldStock[p.sku] ?? selectedAgent.heldStock[p.productName] ?? 0;
                        return DropdownMenuItem(
                          value: p.sku,
                          child: Text(
                            '${p.productName} [${p.sku}] • $curCustody in custody',
                            style: GoogleFonts.inter(fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setModalState(() => selectedProductSku = val);
                      },
                    ),
                    const SizedBox(height: 12),

                    // 3. Movement Inputs (Sold, Returned, DC Restock)
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: unitsSoldCtrl,
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setModalState(() {}),
                            decoration: const InputDecoration(
                              labelText: 'Units Sold Today *',
                              hintText: 'Delivered',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: unitsReturnedCtrl,
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setModalState(() {}),
                            decoration: const InputDecoration(
                              labelText: 'Units Returned',
                              hintText: 'Failed/POD',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: dcRestockCtrl,
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setModalState(() {}),
                            decoration: const InputDecoration(
                              labelText: 'DC Restock',
                              hintText: 'Inbound',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Inbound DC Hub Selector
                    Row(
                      children: [
                        Text('Dispatch DC Hub for Restock: ',
                            style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B))),
                        DropdownButton<String>(
                          value: selectedDc,
                          isDense: true,
                          underline: const SizedBox(),
                          items: const [
                            DropdownMenuItem(value: 'Abuja Central DC', child: Text('Abuja Central DC')),
                            DropdownMenuItem(value: 'Lagos Central DC', child: Text('Lagos Central DC')),
                          ],
                          onChanged: (val) {
                            if (val != null) setModalState(() => selectedDc = val);
                          },
                        ),
                        const Spacer(),
                        Text(
                          'Shelf Stock: $currentDcShelfStock units',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF0284C7),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Live Equation Balance Card
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Starting Agent Custody',
                                  style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B))),
                              Text('$initialCustody units',
                                  style: GoogleFonts.jetBrainsMono(fontSize: 12.5, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('+ New Replenishment from DC',
                                  style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF0284C7))),
                              Text('+$dcReplenish units',
                                  style: GoogleFonts.jetBrainsMono(
                                      fontSize: 12.5, fontWeight: FontWeight.bold, color: const Color(0xFF0284C7))),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('- Delivered Daily Sales',
                                  style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF059669))),
                              Text('-$soldUnits units',
                                  style: GoogleFonts.jetBrainsMono(
                                      fontSize: 12.5, fontWeight: FontWeight.bold, color: const Color(0xFF059669))),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('- Returns / Damaged from Field',
                                  style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFFDC2626))),
                              Text('-$returnedUnits units',
                                  style: GoogleFonts.jetBrainsMono(
                                      fontSize: 12.5, fontWeight: FontWeight.bold, color: const Color(0xFFDC2626))),
                            ],
                          ),
                          const Divider(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('= Balanced Closing Custody',
                                  style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold)),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '$balancedClosing units',
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF059669),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Customer & Order Information
                    Text('4. CUSTOMER & ORDER DETAILS',
                        style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.bold, color: const Color(0xFF64748B))),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: customerNameCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Customer Name',
                              hintText: 'Walk-in / Recipient',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: customerPhoneCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Phone Number',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: orderRefCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Order / Waybill #',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: paymentMethod,
                            decoration: const InputDecoration(
                              labelText: 'Payment Mode',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(value: 'cash_cod', child: Text('Cash COD')),
                              DropdownMenuItem(value: 'transfer', child: Text('Direct Transfer')),
                              DropdownMenuItem(value: 'pos', child: Text('POS Terminal')),
                            ],
                            onChanged: (val) {
                              if (val != null) setModalState(() => paymentMethod = val);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Gross COD Collected Banner
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Gross COD Remittance: ${CurrencyFormatter.formatNaira(totalAmount)}',
                                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                'Will immediately debit $soldUnits units from ${selectedAgent.name}',
                                style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF059669)),
                              ),
                            ],
                          ),
                          const Spacer(),
                          Text(
                            CurrencyFormatter.formatNaira(totalAmount),
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF059669),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Submit Button with Strict Confirmation Modal
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.check_circle_rounded, size: 20),
                        label: Text(
                          'Confirm & Post Daily Sales ($soldUnits Units)',
                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.orange,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: (soldUnits <= 0 && dcReplenish <= 0 && returnedUnits <= 0)
                            ? null
                            : () async {
                                final custName = customerNameCtrl.text.trim().isNotEmpty
                                    ? customerNameCtrl.text.trim()
                                    : 'Field Recipient';

                                final prodTitle = chosenProduct?.productName ?? selectedProductSku!;

                                // Strict Confirmation Modal
                                final confirmed = await NovaCriticalActionConfirmationModal.show(
                                  context: context,
                                  title: 'Confirm Daily Sales & Balance Stock',
                                  actionName: 'Post Sales for ${selectedAgent.name}',
                                  promptMessage:
                                      'You are about to record daily sales and balance stock for ${selectedAgent.name} on $prodTitle. The system will subtract $soldUnits units from physical custody, update network stock, and adjust DC shelves.',
                                  valuesets: {
                                    'Selling Agent': '${selectedAgent.name} (${selectedAgent.agentCode})',
                                    'Product Item': prodTitle,
                                    'Units Sold': '$soldUnits units',
                                    'Units Returned': '$returnedUnits units',
                                    'Inbound Replenishment': '+$dcReplenish units (from $selectedDc)',
                                    'New Custody Balance': '$balancedClosing units',
                                    'Gross COD Collected': CurrencyFormatter.formatNaira(totalAmount),
                                    'Payment Mode': paymentMethod.toUpperCase(),
                                    'Customer': custName,
                                    'Authorizing Operator': operatorName,
                                  },
                                  operatorAccount: operatorName,
                                  confirmLabel: 'Confirm & Apply Balancing',
                                  cancelLabel: 'Cancel / Abort',
                                  brandColor: AppColors.orange,
                                  isDestructive: false,
                                );

                                if (!confirmed) return;

                                final saleRecord = AgentDailySaleRecord(
                                  id: UuidHelper.generate(),
                                  agentId: selectedAgent.id,
                                  agentName: selectedAgent.name,
                                  agentCode: selectedAgent.agentCode,
                                  orderReference: orderRefCtrl.text.trim(),
                                  customerName: custName,
                                  customerPhone: customerPhoneCtrl.text.trim(),
                                  deliveryLocation: deliveryLocCtrl.text.trim(),
                                  items: [
                                    AgentDailySaleItem(
                                      sku: selectedProductSku!,
                                      productName: prodTitle,
                                      quantity: soldUnits,
                                      unitPrice: unitPrice,
                                    ),
                                  ],
                                  totalAmount: totalAmount,
                                  paymentMethod: paymentMethod,
                                  status: 'delivered_collected',
                                  loggedBy: operatorName,
                                  timestamp: DateTime.now(),
                                  notes: notesCtrl.text.trim(),
                                  merchantId: selectedMerchantId,
                                  merchantName: chosenProduct?.merchantName,
                                  replenishedUnits: dcReplenish,
                                  returnedUnits: returnedUnits,
                                  dcName: selectedDc,
                                );

                                await notifier.recordAgentDailySale(saleRecord);

                                if (ctx.mounted) {
                                  Navigator.pop(ctx);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                          'Daily sale posted successfully! $soldUnits units deducted from ${selectedAgent.name}. Closing balance: $balancedClosing units.'),
                                      backgroundColor: const Color(0xFF10B981),
                                    ),
                                  );
                                }
                              },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
