import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/presentation/widgets/change_password_modal.dart';
import '../../domain/entities/merchant_inventory_models.dart';
import '../providers/merchant_inventory_provider.dart';
import '../widgets/merchant_create_inbound_request_modal.dart';
import '../widgets/merchant_edit_product_modal.dart';
import '../widgets/merchant_log_agent_sales_modal.dart';

class MerchantInventoryMobilePortalPage extends ConsumerStatefulWidget {
  const MerchantInventoryMobilePortalPage({super.key});

  @override
  ConsumerState<MerchantInventoryMobilePortalPage> createState() =>
      _MerchantInventoryMobilePortalPageState();
}

class _MerchantInventoryMobilePortalPageState
    extends ConsumerState<MerchantInventoryMobilePortalPage> {
  final _currencyFormat =
      NumberFormat.currency(locale: 'en_NG', symbol: '₦', decimalDigits: 0);
  final _shortDateFormat = DateFormat('MMM dd, yyyy');
  final _searchCtrl = TextEditingController();
  final _agentSearchCtrl = TextEditingController();
  String _agentTypeFilter = 'all'; // 'all', 'fleet', '3pl', 'ext_pda'

  @override
  void initState() {
    super.initState();
    _agentSearchCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _agentSearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.logout_rounded,
                color: Color(0xFFEF4444), size: 22),
            const SizedBox(width: 8),
            Text('Sign Out',
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Text(
          'Are you sure you want to exit the Merchant Inventory Console?',
          style: GoogleFonts.inter(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Sign Out',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      ref.read(authProvider.notifier).logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final inventoryState = ref.watch(merchantInventoryProvider);
    final notifier = ref.read(merchantInventoryProvider.notifier);

    final merchantName = user?.clientCompanyName ?? inventoryState.merchantName;
    final officerName = user?.fullName.isNotEmpty == true
        ? user!.fullName
        : 'Amaka Obi (Stock Keeper)';

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF090D16) : const Color(0xFFF8FAFC),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : Colors.white,
            border: Border(
              bottom: BorderSide(
                color:
                    isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
              ),
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.inventory_2_rounded,
                      color: Color(0xFF0284C7),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                merchantName,
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF0F172A),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0284C7)
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'STOCK OPS',
                                style: GoogleFonts.inter(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF0284C7),
                                ),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          officerName,
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            color: isDark
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.key_rounded, size: 20),
                    tooltip: 'Change Password',
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    onPressed: () {
                      final user = ref.read(authProvider).user;
                      ChangePasswordModal.show(context, email: user?.email);
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.logout_rounded, size: 20),
                    tooltip: 'Sign Out',
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF64748B),
                    onPressed: _handleLogout,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // KPI Summary Row (Compact Handheld Friendly)
            _buildKpiBanner(inventoryState, isDark),

            // Tab Body
            Expanded(
              child: IndexedStack(
                index: inventoryState.activeTab,
                children: [
                  _buildStockOverviewTab(inventoryState, notifier, isDark),
                  _buildInboundConsignmentsTab(
                      inventoryState, notifier, isDark),
                  _buildAgentBalancingTab(inventoryState, notifier, isDark),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : Colors.white,
          border: Border(
            top: BorderSide(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
            ),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: inventoryState.activeTab,
          onTap: notifier.setActiveTab,
          backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
          selectedItemColor: const Color(0xFF0284C7),
          unselectedItemColor:
              isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
          selectedLabelStyle:
              GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700),
          unselectedLabelStyle:
              GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500),
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.warehouse_rounded),
              activeIcon:
                  Icon(Icons.warehouse_rounded, color: Color(0xFF0284C7)),
              label: 'DC Shelves',
            ),
            BottomNavigationBarItem(
              icon: Badge(
                isLabelVisible: inventoryState.totalPendingInboundUnits > 0,
                label: Text('${inventoryState.totalPendingInboundUnits}'),
                child: const Icon(Icons.local_shipping_rounded),
              ),
              activeIcon: const Icon(Icons.local_shipping_rounded,
                  color: Color(0xFF0284C7)),
              label: 'Inbound DC',
            ),
            BottomNavigationBarItem(
              icon: Badge(
                isLabelVisible: inventoryState.flaggedDiscrepancyCount > 0,
                backgroundColor: const Color(0xFFEF4444),
                label: Text('${inventoryState.flaggedDiscrepancyCount}'),
                child: const Icon(Icons.point_of_sale_rounded),
              ),
              activeIcon: const Icon(Icons.point_of_sale_rounded,
                  color: Color(0xFF0284C7)),
              label: 'Agent Sales',
            ),
          ],
        ),
      ),
      floatingActionButton: inventoryState.activeTab == 1
          ? FloatingActionButton.extended(
              onPressed: () => MerchantCreateInboundRequestModal.show(context),
              backgroundColor: const Color(0xFF0284C7),
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: Text('Inbound Request',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
            )
          : (inventoryState.activeTab == 2
              ? FloatingActionButton.extended(
                  onPressed: () => MerchantLogAgentSalesModal.show(context),
                  backgroundColor: const Color(0xFF059669),
                  foregroundColor: Colors.white,
                  icon: const Icon(Icons.sync_rounded),
                  label: Text('Log Daily Sales',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                )
              : null),
    );
  }

  Widget _buildKpiBanner(MerchantInventoryState state, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      color: isDark ? const Color(0xFF131D31) : const Color(0xFFF1F5F9),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildKpiChip('DC Shelves', '${state.totalInDcShelves} pcs',
                const Color(0xFF0284C7), isDark),
            const SizedBox(width: 8),
            _buildKpiChip(
                'In Agent Custody',
                '${state.totalInAgentCustody} pcs',
                const Color(0xFF7C3AED),
                isDark),
            const SizedBox(width: 8),
            _buildKpiChip('Sold Today', '${state.totalSalesDeliveredToday} pcs',
                const Color(0xFF059669), isDark),
            const SizedBox(width: 8),
            _buildKpiChip(
                'QC Quarantine',
                '${state.totalDefectiveQuarantine} spoilt',
                const Color(0xFFEF4444),
                isDark),
            const SizedBox(width: 8),
            _buildKpiChip(
                'Stock Valuation',
                _currencyFormat.format(state.totalStockValuation),
                const Color(0xFFD97706),
                isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiChip(String label, String value, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: GoogleFonts.inter(
                fontSize: 11,
                color:
                    isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
          ),
          Text(
            value,
            style: GoogleFonts.inter(
                fontSize: 11.5, fontWeight: FontWeight.w800, color: color),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // TAB 0: LIVE DC SHELVES & VELOCITY
  // =========================================================================
  Widget _buildStockOverviewTab(
    MerchantInventoryState state,
    MerchantInventoryNotifier notifier,
    bool isDark,
  ) {
    final products = state.filteredProducts;

    return Column(
      children: [
        // Filter & Search Toolbar
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: notifier.setSearchQuery,
                  decoration: InputDecoration(
                    hintText: 'Search product or SKU...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    isDense: true,
                    filled: true,
                    fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                initialValue: state.selectedDcFilter,
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: isDark
                            ? const Color(0xFF334155)
                            : const Color(0xFFCBD5E1)),
                  ),
                  child: const Icon(Icons.filter_list_rounded, size: 18),
                ),
                onSelected: notifier.setDcFilter,
                itemBuilder: (ctx) => [
                  'All Warehouses',
                  'Abuja Central DC',
                  'Lagos Central DC',
                ].map((f) => PopupMenuItem(value: f, child: Text(f))).toList(),
              ),
            ],
          ),
        ),

        // Product Cards List
        Expanded(
          child: products.isEmpty
              ? Center(
                  child: Text(
                    'No products match your criteria',
                    style: GoogleFonts.inter(color: const Color(0xFF94A3B8)),
                  ),
                )
              : ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  itemCount: products.length,
                  itemBuilder: (ctx, index) {
                    final p = products[index];
                    return _buildProductCard(p, state.selectedDcFilter, isDark);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildProductCard(
      MerchantProductStockView p, String dcFilter, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product Thumbnail Image
              Container(
                width: 56,
                height: 56,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF0F172A)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF334155)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: p.imageUrl != null && p.imageUrl!.isNotEmpty
                    ? Image.network(
                        p.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (ctx, err, stack) => const Icon(
                          Icons.inventory_2_outlined,
                          size: 24,
                          color: Color(0xFF94A3B8),
                        ),
                      )
                    : const Icon(
                        Icons.inventory_2_outlined,
                        size: 24,
                        color: Color(0xFF94A3B8),
                      ),
              ),

              // Title, SKU & Price
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            p.name,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        // Quick Edit Product Action Button
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints:
                              const BoxConstraints(minWidth: 28, minHeight: 28),
                          tooltip: 'Edit product details & image',
                          icon: const Icon(Icons.edit_outlined,
                              size: 18, color: Color(0xFF0284C7)),
                          onPressed: () =>
                              MerchantEditProductModal.show(context, p),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFF0284C7).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            p.sku,
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0284C7),
                            ),
                          ),
                        ),
                        Text(
                          p.category,
                          style: GoogleFonts.inter(
                              fontSize: 11, color: const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                    if (p.description != null && p.description!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        p.description!,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                          color: isDark
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF475569),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Text(
                'Unit Price: ${_currencyFormat.format(p.unitPrice)}',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF059669),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF0284C7).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Total System Stock: ${p.totalSystemStock} pcs',
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0284C7),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 10),

          // DC Shelves Breakdown (Abuja, Lagos, Kano)
          Text(
            'Distribution Center Warehouses (Physical Shelves)',
            style: GoogleFonts.inter(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF64748B)),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: p.dcShelves.entries.map((entry) {
              final dc = entry.key;
              final qty = entry.value;
              final spoilt = p.dcDefectQuarantine[dc] ?? 0;
              final isMatch = dcFilter == 'All Warehouses' ||
                  dc.toLowerCase().contains(dcFilter.toLowerCase());

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: isMatch
                      ? (isDark
                          ? const Color(0xFF0F172A)
                          : const Color(0xFFF1F5F9))
                      : (isDark
                          ? const Color(0xFF1E293B)
                          : const Color(0xFFF8FAFC)),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isMatch
                        ? const Color(0xFF0284C7).withValues(alpha: 0.4)
                        : Colors.transparent,
                  ),
                ),
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 4,
                  children: [
                    Text(
                      '$dc: ',
                      style: GoogleFonts.inter(
                          fontSize: 11, fontWeight: FontWeight.w500),
                    ),
                    Text(
                      '$qty units',
                      style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0284C7)),
                    ),
                    if (spoilt > 0)
                      Text(
                        '($spoilt spoilt)',
                        style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFFEF4444)),
                      ),
                  ],
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 10),
          // Agent Custody Breakdown
          Text(
            'In Agent Custody (Field Delivery)',
            style: GoogleFonts.inter(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF64748B)),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: p.agentCustody.entries.map((entry) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF7C3AED).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${entry.key}: ${entry.value} pcs',
                  style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF7C3AED)),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 10),
          // Stock Ratio Distribution Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Stock Balance Distribution',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${p.totalSystemStock} pcs total',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 6,
              child: Builder(
                builder: (context) {
                  final totalShelves = p.dcShelves.values.fold<int>(0, (s, q) => s + q);
                  final totalCustody = p.agentCustody.values.fold<int>(0, (s, q) => s + q);
                  final totalSpoilt = p.dcDefectQuarantine.values.fold<int>(0, (s, q) => s + q);
                  final totalAll = (totalShelves + totalCustody + totalSpoilt).clamp(1, 999999);
                  final shelfFlex = ((totalShelves / totalAll) * 100).round().clamp(totalShelves > 0 ? 1 : 0, 100);
                  final custodyFlex = ((totalCustody / totalAll) * 100).round().clamp(totalCustody > 0 ? 1 : 0, 100);
                  final spoiltFlex = ((totalSpoilt / totalAll) * 100).round().clamp(totalSpoilt > 0 ? 1 : 0, 100);

                  final hasSegments = shelfFlex > 0 || custodyFlex > 0 || spoiltFlex > 0;
                  if (!hasSegments) {
                    return Container(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0));
                  }

                  return Row(
                    children: [
                      if (shelfFlex > 0)
                        Expanded(flex: shelfFlex, child: Container(color: const Color(0xFF0284C7))),
                      if (custodyFlex > 0)
                        Expanded(flex: custodyFlex, child: Container(color: const Color(0xFF7C3AED))),
                      if (spoiltFlex > 0)
                        Expanded(flex: spoiltFlex, child: Container(color: const Color(0xFFEF4444))),
                    ],
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 12),

          // 1-Tap Quick Action Buttons for Warehouse Stock Ops
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0284C7),
                    side: BorderSide(color: const Color(0xFF0284C7).withValues(alpha: 0.5)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  onPressed: () => MerchantCreateInboundRequestModal.show(context),
                  icon: const Icon(Icons.add_shopping_cart_rounded, size: 16),
                  label: Text(
                    'Inbound',
                    style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    elevation: 0,
                  ),
                  onPressed: () => MerchantLogAgentSalesModal.show(context, initialSku: p.sku),
                  icon: const Icon(Icons.sync_rounded, size: 16),
                  label: Text(
                    'Log Daily Sales',
                    style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // TAB 1: INBOUND CONSIGNMENTS & QC DEFECT INSPECTION
  // =========================================================================
  Widget _buildInboundConsignmentsTab(
    MerchantInventoryState state,
    MerchantInventoryNotifier notifier,
    bool isDark,
  ) {
    final shipments = state.filteredInboundShipments;

    return Column(
      children: [
        // Action Bar
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Inbound Consignments (${shipments.length})',
                  style: GoogleFonts.inter(
                      fontSize: 14, fontWeight: FontWeight.w800),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
                onPressed: () =>
                    MerchantCreateInboundRequestModal.show(context),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text('New Consignment',
                    style: GoogleFonts.inter(
                        fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),

        Expanded(
          child: shipments.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.local_shipping_outlined,
                          size: 48, color: Color(0xFF94A3B8)),
                      const SizedBox(height: 12),
                      Text(
                        'No Inbound Consignments Recorded',
                        style: GoogleFonts.inter(
                            fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tap "+ New Consignment" to dispatch products to a DC.',
                        style: GoogleFonts.inter(
                            fontSize: 12, color: const Color(0xFF64748B)),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  itemCount: shipments.length,
                  itemBuilder: (ctx, index) {
                    final s = shipments[index];
                    return _buildInboundShipmentCard(s, isDark);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildInboundShipmentCard(MerchantInboundShipment s, bool isDark) {
    Color statusColor;
    String statusLabel;
    IconData statusIcon;

    if (s.isReceivedClean) {
      statusColor = const Color(0xFF059669);
      statusLabel = 'VERIFIED & CREDITED';
      statusIcon = Icons.verified_rounded;
    } else if (s.isReceivedWithDefects) {
      statusColor = const Color(0xFFF59E0B);
      statusLabel = 'DEFECTS QUARANTINED';
      statusIcon = Icons.warning_rounded;
    } else {
      statusColor = const Color(0xFF0284C7);
      statusLabel = 'IN TRANSIT';
      statusIcon = Icons.local_shipping_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  s.waybillNumber,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0284C7),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, color: statusColor, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      statusLabel,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            s.productName,
            style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),

          // Route info
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Destination DC',
                        style: GoogleFonts.inter(
                            fontSize: 10.5, color: const Color(0xFF64748B)),
                      ),
                      Text(
                        s.targetDcName,
                        style: GoogleFonts.inter(
                            fontSize: 12, fontWeight: FontWeight.w700),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Expected Shipped',
                      style: GoogleFonts.inter(
                            fontSize: 10.5, color: const Color(0xFF64748B)),
                    ),
                    Text(
                      '${s.expectedQuantity} units',
                      style: GoogleFonts.inter(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0284C7)),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Carrier info
          if (s.carrierDriverName.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Carrier: ${s.carrierDriverName} (${s.carrierPlate}) • Phone: ${s.carrierPhone}',
              style: GoogleFonts.inter(
                  fontSize: 11, color: const Color(0xFF64748B)),
            ),
          ],

          // QC Reception Defect Breakdown (from DC Stock Officer)
          if (s.isCompleted) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: s.spoiltQuantity > 0
                    ? (isDark
                        ? const Color(0xFF2A1B18)
                        : const Color(0xFFFFFBEB))
                    : (isDark
                        ? const Color(0xFF13281E)
                        : const Color(0xFFF0FDF4)),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: s.spoiltQuantity > 0
                      ? const Color(0xFFF59E0B).withValues(alpha: 0.3)
                      : const Color(0xFF059669).withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'DC Physical Inspection Report',
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: s.spoiltQuantity > 0
                                ? const Color(0xFFD97706)
                                : const Color(0xFF059669),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        s.stagingBay ?? 'Staging Bay A',
                        style: GoogleFonts.inter(
                            fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      Text(
                        'Good Accepted: ${s.acceptedQuantity} pcs',
                        style: GoogleFonts.inter(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF059669)),
                      ),
                      Text(
                        'Spoilt: ${s.spoiltQuantity} pcs',
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: s.spoiltQuantity > 0
                              ? const Color(0xFFEF4444)
                              : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),

                  // Defect Status Details
                  if (s.defectBreakdown.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: s.defectBreakdown.entries.map((e) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFFEF4444).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${e.key}: ${e.value} pcs',
                            style: GoogleFonts.inter(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFFEF4444)),
                          ),
                        );
                      }).toList(),
                    ),
                  ],

                  if (s.dcInspectorName != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Verified by: ${s.dcInspectorName}',
                      style: GoogleFonts.inter(
                          fontSize: 10.5, color: const Color(0xFF64748B)),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // =========================================================================
  // TAB 2: AGENT DAILY SALES & SYSTEM STOCK BALANCING
  // =========================================================================
  Widget _buildAgentBalancingTab(
    MerchantInventoryState state,
    MerchantInventoryNotifier notifier,
    bool isDark,
  ) {
    final agents = state.agents;
    final records = state.salesRecords;

    // Filter agents by search query & filter chips
    final q = _agentSearchCtrl.text.toLowerCase().trim();
    final filteredAgents = agents.where((agent) {
      final isExt = agent.agentType.toLowerCase().contains('external') || agent.code.startsWith('EXT-');
      final isFleet = agent.agentType.contains('Fleet') || agent.code.startsWith('NX-');
      if (_agentTypeFilter == 'fleet' && !isFleet) return false;
      if (_agentTypeFilter == '3pl' && (isFleet || isExt)) return false;
      if (_agentTypeFilter == 'ext_pda' && !isExt) return false;
      if (q.isNotEmpty) {
        if (!agent.name.toLowerCase().contains(q) &&
            !agent.code.toLowerCase().contains(q) &&
            !agent.state.toLowerCase().contains(q)) {
          return false;
        }
      }
      return true;
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Quick Log Action
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Partner Agent Custody',
                      style: GoogleFonts.inter(
                          fontSize: 15, fontWeight: FontWeight.w800),
                    ),
                    Text(
                      'Balancing: Opening + Inbound - Sales - Returns = Closing',
                      style: GoogleFonts.inter(
                          fontSize: 11, color: const Color(0xFF64748B)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
                onPressed: () => MerchantLogAgentSalesModal.show(context),
                icon: const Icon(Icons.sync_rounded, size: 18),
                label: Text('Log Sales',
                    style: GoogleFonts.inter(
                        fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Search & Filter Toolbar for Agents
          TextField(
            controller: _agentSearchCtrl,
            decoration: InputDecoration(
              hintText: 'Search courier by name, code or state...',
              hintStyle: GoogleFonts.inter(fontSize: 12.5),
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              suffixIcon: _agentSearchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () => _agentSearchCtrl.clear(),
                    )
                  : null,
              isDense: true,
              filled: true,
              fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 8),

          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildAgentFilterChip('All Couriers (${agents.length})', 'all', isDark),
                const SizedBox(width: 6),
                _buildAgentFilterChip('Internal Fleet', 'fleet', isDark),
                const SizedBox(width: 6),
                _buildAgentFilterChip('3PL Logistics', '3pl', isDark),
                const SizedBox(width: 6),
                _buildAgentFilterChip('External PDAs', 'ext_pda', isDark),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Agents Custody Overview Cards
          if (filteredAgents.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 30),
              child: Center(
                child: Text(
                  'No delivery couriers match your filter',
                  style: GoogleFonts.inter(color: const Color(0xFF94A3B8)),
                ),
              ),
            )
          else
            ...filteredAgents.map((agent) {
              final isExt = agent.agentType.toLowerCase().contains('external') || agent.code.startsWith('EXT-');
              final isFleet = agent.agentType.contains('Fleet') || agent.code.startsWith('NX-');

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF334155)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF7C3AED)
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.two_wheeler_rounded,
                                    color: Color(0xFF7C3AED), size: 18),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        if (isExt) ...[
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                            margin: const EdgeInsets.only(right: 6),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              'EXT-PDA',
                                              style: GoogleFonts.inter(
                                                fontSize: 9,
                                                fontWeight: FontWeight.w800,
                                                color: const Color(0xFFF59E0B),
                                              ),
                                            ),
                                          ),
                                        ] else if (isFleet) ...[
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                            margin: const EdgeInsets.only(right: 6),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF0284C7).withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              'FLEET',
                                              style: GoogleFonts.inter(
                                                fontSize: 9,
                                                fontWeight: FontWeight.w800,
                                                color: const Color(0xFF0284C7),
                                              ),
                                            ),
                                          ),
                                        ],
                                        Expanded(
                                          child: Text(
                                            agent.name,
                                            style: GoogleFonts.inter(
                                                fontSize: 13.5,
                                                fontWeight: FontWeight.w800),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      '${agent.agentType} • ${agent.code} • ${agent.state}',
                                      style: GoogleFonts.inter(
                                          fontSize: 11,
                                          color: const Color(0xFF64748B)),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFF7C3AED).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${agent.totalHeldUnits} pcs held',
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF7C3AED),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Divider(height: 1),
                    const SizedBox(height: 8),

                    // Product items held
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: agent.productCustody.entries.map((entry) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF0F172A)
                                : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isDark
                                  ? const Color(0xFF334155)
                                  : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${entry.key}: ',
                                style: GoogleFonts.inter(
                                    fontSize: 11, fontWeight: FontWeight.w500),
                              ),
                              Text(
                                '${entry.value} units',
                                style: GoogleFonts.inter(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF0284C7)),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 10),

                    // Quick Action button to balance for this agent
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () => MerchantLogAgentSalesModal.show(context,
                            initialAgent: agent),
                        icon: const Icon(Icons.edit_note_rounded, size: 16),
                        label: Text('Log Sales & Balance This Agent',
                            style: GoogleFonts.inter(
                                fontSize: 11.5, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              );
            }),

          const SizedBox(height: 16),
          // History of Daily Sales Logs
          Text(
            'Daily Sales Reconciliation Audit History (${records.length})',
            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),

          ...records.map((r) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: r.discrepancyFlagged
                      ? const Color(0xFFEF4444).withValues(alpha: 0.5)
                      : (isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFFE2E8F0)),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          r.agentName,
                          style: GoogleFonts.inter(
                              fontSize: 12.5, fontWeight: FontWeight.w800),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _shortDateFormat.format(r.date),
                        style: GoogleFonts.inter(
                            fontSize: 11, color: const Color(0xFF64748B)),
                      ),
                    ],
                  ),
                  Text(
                    '${r.productName} (${r.sku})',
                    style: GoogleFonts.inter(
                        fontSize: 11.5, color: const Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 6),

                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    alignment: WrapAlignment.spaceBetween,
                    children: [
                      Text(
                        'Opening: ${r.openingCustody}',
                        style: GoogleFonts.inter(
                            fontSize: 11, color: const Color(0xFF64748B)),
                      ),
                      Text(
                        'Sold: -${r.unitsSold}',
                        style: GoogleFonts.inter(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF059669)),
                      ),
                      if (r.unitsReturned > 0)
                        Text(
                          'Returned: -${r.unitsReturned}',
                          style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFFEF4444)),
                        ),
                      Text(
                        'Closing: ${r.closingCustody} pcs',
                        style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF0284C7)),
                      ),
                    ],
                  ),

                  // Ambush Audit Results (if performed)
                  if (r.isAuditAmbush) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: r.discrepancyFlagged
                            ? const Color(0xFFEF4444).withValues(alpha: 0.12)
                            : const Color(0xFF059669).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            r.discrepancyFlagged
                                ? Icons.warning_amber_rounded
                                : Icons.check_circle_rounded,
                            size: 16,
                            color: r.discrepancyFlagged
                                ? const Color(0xFFEF4444)
                                : const Color(0xFF059669),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Physical Count: ${r.physicalAuditCount} • Variance: ${r.variancePercentage?.toStringAsFixed(1)}%',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: r.discrepancyFlagged
                                    ? const Color(0xFFEF4444)
                                    : const Color(0xFF059669),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  if (r.loggedBy != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Balanced by: ${r.loggedBy}',
                      style: GoogleFonts.inter(
                          fontSize: 10.5, color: const Color(0xFF64748B)),
                    ),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildAgentFilterChip(String label, String value, bool isDark) {
    final isSelected = _agentTypeFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) setState(() => _agentTypeFilter = value);
      },
      labelStyle: GoogleFonts.inter(
        fontSize: 11.5,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        color: isSelected
            ? Colors.white
            : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
      ),
      selectedColor: const Color(0xFF0284C7),
      backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
      side: BorderSide(
        color: isSelected
            ? const Color(0xFF0284C7)
            : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }
}
