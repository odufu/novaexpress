import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../core/helpers/formatters.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../client_portal/presentation/widgets/pangea_excel_data_table.dart';
import '../../../domain/entities/admin_models.dart';
import '../../providers/admin_console_provider.dart';
import '../../widgets/admin_assign_agent_merchants_modal.dart';
import '../../widgets/admin_edit_agent_modal.dart';
import '../../widgets/admin_inbound_qc_modal.dart';
import '../../widgets/admin_log_daily_sale_modal.dart';
import '../../widgets/admin_manage_agent_custody_modal.dart';
import '../../widgets/admin_manage_products_modal.dart';
import '../../widgets/admin_metric_card.dart';
import '../../widgets/admin_onboard_product_modal.dart';
import '../../widgets/admin_stock_holder_detail_modal.dart';

class AdminGlobalStockTab extends ConsumerWidget {
  const AdminGlobalStockTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(adminConsoleProvider);
    final notifier = ref.read(adminConsoleProvider.notifier);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final allHolders = state.stockHolderRows;
    final displayedHolders = state.filteredStockHolderRows;
    final displayedProducts = state.filteredGlobalStock;

    // Direct aggregation from holder rows ensures 100% exact match with table rows
    final totalWarehouseUnits = allHolders
        .where((h) => h.isDcShelf)
        .fold<int>(0, (s, h) => s + h.totalUnits);
    final totalCustodyUnits = allHolders
        .where((h) => !h.isDcShelf)
        .fold<int>(0, (s, h) => s + h.totalUnits);
    final totalStockUnits = totalWarehouseUnits + totalCustodyUnits;
    final lowStockCount =
        displayedProducts.where((i) => i.lowStockDcCount > 0).length;

    final isDesktop = MediaQuery.of(context).size.width >= 900;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Sleek, high-density Metrics Header (Compact ribbon by default, expandable to cards)
          AdminMetricsHeader(
            metrics: [
              AdminMetricData(
                title: 'Total Network Stock',
                value: '$totalStockUnits',
                icon: Icons.inventory_2_outlined,
                iconColor: const Color(0xFF3B82F6),
                subtitle: 'Shelf + Agent custody',
                tooltip:
                    'Combined physical inventory units across all distribution center shelves and operating agent fleets',
              ),
              AdminMetricData(
                title: 'DC Warehouse Shelves',
                value: '$totalWarehouseUnits',
                icon: Icons.warehouse_rounded,
                iconColor: const Color(0xFF10B981),
                subtitle: 'in DC storage racks',
                tooltip:
                    'Units physically located inside Abuja and Lagos distribution centers',
              ),
              AdminMetricData(
                title: 'Agent Fleet Custody',
                value: '$totalCustodyUnits',
                icon: Icons.local_shipping_outlined,
                iconColor: AppColors.orange,
                subtitle:
                    'NovaXpress + 3PLs (${allHolders.where((h) => !h.isDcShelf).length} Agents)',
                tooltip:
                    'Units currently held in courier vehicles, in-transit batches, and 3PL agent custody across the CRM network',
              ),
              AdminMetricData(
                title: 'Stockout Advisories',
                value: '$lowStockCount',
                icon: Icons.warning_amber_rounded,
                iconColor: const Color(0xFFEF4444),
                subtitle: '2-week lead-time alerts',
                tooltip:
                    'Products with station-level stock reaching minimum reorder threshold',
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 2. Data Representation: DataTable on Desktop (with filters in heading), Cards on Mobile
          if (isDesktop)
            _buildDesktopStockDataTable(
                context,
                ref,
                state,
                notifier,
                displayedHolders,
                displayedProducts,
                state.merchants,
                allHolders.length,
                isDark)
          else ...[
            _buildMobileFilterAndActionBar(
                context, ref, state, notifier, allHolders.length, isDark),
            const SizedBox(height: 12),
            _buildMobileStockCardList(
                context, ref, displayedHolders, displayedProducts, state.merchants, isDark),
          ],
        ],
      ),
    );
  }

  Widget _buildMobileFilterAndActionBar(
    BuildContext context,
    WidgetRef ref,
    AdminConsoleState state,
    AdminConsoleNotifier notifier,
    int totalHoldersCount,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 10,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // Left: Dropdown Filters
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Merchant Filter
              SizedBox(
                width: 190,
                child: DropdownButtonFormField<String>(
                  value: state.stockMerchantFilter,
                  decoration: _filterInputDeco(
                      'Filter by Merchant', Icons.storefront_outlined, isDark),
                  isExpanded: true,
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      color: isDark ? Colors.white : const Color(0xFF0F172A)),
                  items: [
                    const DropdownMenuItem(
                        value: 'all', child: Text('All Merchants')),
                    ...state.merchants.map((m) {
                      return DropdownMenuItem(
                        value: m.id,
                        child: Text(m.businessName,
                            overflow: TextOverflow.ellipsis),
                      );
                    }),
                  ],
                  onChanged: (val) {
                    if (val != null) notifier.setStockMerchantFilter(val);
                  },
                ),
              ),

              // Hub/Warehouse Filter (Abuja vs Lagos)
              SizedBox(
                width: 175,
                child: DropdownButtonFormField<String>(
                  value: state.stockHubFilter,
                  decoration: _filterInputDeco(
                      'Filter by DC Hub', Icons.hub_outlined, isDark),
                  isExpanded: true,
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      color: isDark ? Colors.white : const Color(0xFF0F172A)),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All DC Hubs')),
                    DropdownMenuItem(
                        value: 'Abuja', child: Text('Abuja Central DC')),
                    DropdownMenuItem(
                        value: 'Lagos', child: Text('Lagos Central DC')),
                  ],
                  onChanged: (val) {
                    if (val != null) notifier.setStockHubFilter(val);
                  },
                ),
              ),

              // Custodian Filter
              SizedBox(
                width: 185,
                child: DropdownButtonFormField<String>(
                  value: state.stockHealthFilter,
                  decoration: _filterInputDeco(
                      'Custodian Filter', Icons.category_outlined, isDark),
                  isExpanded: true,
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      color: isDark ? Colors.white : const Color(0xFF0F172A)),
                  items: [
                    DropdownMenuItem(
                        value: 'all',
                        child: Text('All Custodians ($totalHoldersCount)')),
                    const DropdownMenuItem(
                        value: 'dc_shelves',
                        child: Text('Warehouse Shelves')),
                    const DropdownMenuItem(
                        value: 'agents', child: Text('All Delivery Agents')),
                    const DropdownMenuItem(
                        value: 'internal_fleet',
                        child: Text('NovaXpress Fleet')),
                    const DropdownMenuItem(
                        value: '3pl_partner',
                        child: Text('3PL Courier Partners')),
                    const DropdownMenuItem(
                        value: 'holding_stock',
                        child: Text('Holding Stock (>0)')),
                    const DropdownMenuItem(
                        value: 'zero_stock',
                        child: Text('Zero Stock (0)')),
                  ],
                  onChanged: (val) {
                    if (val != null) notifier.setStockHealthFilter(val);
                  },
                ),
              ),

              // Search Box
              SizedBox(
                width: 190,
                child: TextField(
                  onChanged: notifier.setSearchQuery,
                  style: GoogleFonts.inter(fontSize: 12),
                  decoration: InputDecoration(
                    hintText: 'Search Agent, Code, DC...',
                    hintStyle: GoogleFonts.inter(
                        fontSize: 11.5, color: const Color(0xFF94A3B8)),
                    prefixIcon: const Icon(Icons.search_rounded,
                        size: 16, color: Color(0xFF64748B)),
                    filled: true,
                    fillColor: isDark
                        ? const Color(0xFF1E293B)
                        : const Color(0xFFF1F5F9),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                          color: isDark
                              ? const Color(0xFF334155)
                              : const Color(0xFFCBD5E1)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                          color: isDark
                              ? const Color(0xFF334155)
                              : const Color(0xFFCBD5E1)),
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Right: Action Buttons
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              // Log Daily Sales
              ElevatedButton.icon(
                icon: const Icon(Icons.point_of_sale_rounded, size: 15),
                label: const Text('Log Daily Sales'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  textStyle: GoogleFonts.inter(
                      fontSize: 12, fontWeight: FontWeight.bold),
                ),
                onPressed: () {
                  AdminLogDailySaleModal.show(context: context);
                },
              ),

              // Inbound Batch & QC
              ElevatedButton.icon(
                icon: const Icon(Icons.verified_outlined, size: 15),
                label: const Text('Inbound Batch & QC'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  textStyle: GoogleFonts.inter(
                      fontSize: 12, fontWeight: FontWeight.bold),
                ),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => const AdminInboundQCModal(),
                  );
                },
              ),

              // Onboard Product
              ElevatedButton.icon(
                icon: const Icon(Icons.add_box_outlined, size: 15),
                label: const Text('Onboard Product'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  textStyle: GoogleFonts.inter(
                      fontSize: 12, fontWeight: FontWeight.bold),
                ),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => const AdminOnboardProductModal(),
                  );
                },
              ),

              // Manage Products (Edit & Delete)
              ElevatedButton.icon(
                icon: const Icon(Icons.settings_suggest_outlined, size: 15),
                label: const Text('Manage Products'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  textStyle: GoogleFonts.inter(
                      fontSize: 12, fontWeight: FontWeight.bold),
                ),
                onPressed: () {
                  AdminManageProductsModal.show(context: context);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopStockDataTable(
    BuildContext context,
    WidgetRef ref,
    AdminConsoleState state,
    AdminConsoleNotifier notifier,
    List<AdminStockHolderRow> holders,
    List<AdminGlobalStockItem> products,
    List<AdminMerchant> merchants,
    int totalHoldersCount,
    bool isDark,
  ) {
    final columns = <ExcelColumnDef<AdminStockHolderRow>>[
      // 1. Agent / Stock Holder Name & Code
      ExcelColumnDef<AdminStockHolderRow>(
        key: 'holder_name',
        label: 'Agent / Stock Holder',
        defaultWidth: 230,
        minWidth: 190,
        sortValue: (row) => row.name,
        searchString: (row) => '${row.name} ${row.code} ${row.phone}',
        cellBuilder: (ctx, row, idx, dark, primary) {
          IconData icon;
          Color iconColor;
          if (row.isDcShelf) {
            icon = Icons.warehouse_rounded;
            iconColor = const Color(0xFF10B981);
          } else if (row.isInternalFleet) {
            icon = Icons.local_shipping_rounded;
            iconColor = const Color(0xFFEA580C);
          } else {
            icon = Icons.delivery_dining_rounded;
            iconColor = const Color(0xFF0284C7);
          }

          return Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, size: 16, color: iconColor),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      row.name,
                      style: GoogleFonts.inter(
                          fontSize: 12.5, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${row.code}${row.phone.isNotEmpty ? " • ${row.phone}" : ""}',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10,
                        color: dark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),

      // 2. Custodian Type
      ExcelColumnDef<AdminStockHolderRow>(
        key: 'holder_type',
        label: 'Custodian Type',
        defaultWidth: 140,
        minWidth: 110,
        sortValue: (row) => row.typeLabel,
        cellBuilder: (ctx, row, idx, dark, primary) {
          Color badgeColor;
          if (row.isDcShelf) {
            badgeColor = const Color(0xFF10B981);
          } else if (row.isInternalFleet) {
            badgeColor = const Color(0xFFEA580C);
          } else {
            badgeColor = const Color(0xFF0284C7);
          }

          return Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                row.typeLabel,
                style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: badgeColor),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          );
        },
      ),

      // 3. Operating Hub
      ExcelColumnDef<AdminStockHolderRow>(
        key: 'hub_name',
        label: 'Operating Hub',
        defaultWidth: 145,
        minWidth: 115,
        sortValue: (row) => row.hubName,
        cellBuilder: (ctx, row, idx, dark, primary) {
          final isAbuja = row.hubName.contains('Abuja');
          final color = isAbuja ? const Color(0xFF0D9488) : const Color(0xFF2563EB);

          return Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                row.hubName,
                style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: color),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          );
        },
      ),

      // 4. Merchants Served
      ExcelColumnDef<AdminStockHolderRow>(
        key: 'merchants',
        label: 'Merchants Served',
        defaultWidth: 160,
        minWidth: 120,
        sortValue: (row) => row.assignedMerchantNames.length,
        cellBuilder: (ctx, row, idx, dark, primary) {
          if (row.isDcShelf) {
            return Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'All Platform Merchants',
                  style: GoogleFonts.inter(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF7C3AED)),
                ),
              ),
            );
          }

          if (row.assignedMerchantNames.isEmpty) {
            return Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'None Assigned',
                style: GoogleFonts.inter(
                    fontSize: 11,
                    color: dark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
              ),
            );
          }

          return Align(
            alignment: Alignment.centerLeft,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: row.assignedMerchantNames.take(2).map((mName) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        mName.replaceAll(' Limited', ''),
                        style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF7C3AED)),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          );
        },
      ),

      // 5. DYNAMIC PRODUCT COLUMNS: Each product is a COLUMN!
      ...products.map((product) {
        final shortLabel = _shortProductName(product.productName);
        return ExcelColumnDef<AdminStockHolderRow>(
          key: 'prod_${product.sku}',
          label: shortLabel,
          group: 'PRODUCT QUANTITIES (UNITS)',
          defaultWidth: 125,
          minWidth: 95,
          align: TextAlign.center,
          sortValue: (row) => row.quantityForSku(product.sku),
          cellBuilder: (ctx, row, idx, dark, primary) {
            final qty = row.quantityForSku(product.sku);
            final hasStock = qty > 0;

            Color textColor;
            Color bgColor;
            if (row.isDcShelf) {
              textColor = hasStock
                  ? const Color(0xFF059669)
                  : (dark ? const Color(0xFF64748B) : const Color(0xFF94A3B8));
              bgColor = const Color(0xFF10B981)
                  .withValues(alpha: hasStock ? 0.14 : 0.05);
            } else if (row.isInternalFleet) {
              textColor = hasStock
                  ? const Color(0xFFEA580C)
                  : (dark ? const Color(0xFF64748B) : const Color(0xFF94A3B8));
              bgColor = const Color(0xFFF97316)
                  .withValues(alpha: hasStock ? 0.14 : 0.05);
            } else {
              textColor = hasStock
                  ? const Color(0xFF0284C7)
                  : (dark ? const Color(0xFF64748B) : const Color(0xFF94A3B8));
              bgColor = const Color(0xFF0284C7)
                  .withValues(alpha: hasStock ? 0.14 : 0.05);
            }

            return Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$qty',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 12,
                    fontWeight: hasStock ? FontWeight.bold : FontWeight.normal,
                    color: textColor,
                  ),
                ),
              ),
            );
          },
        );
      }),

      // 6. TOTAL CUSTODY (Row Total Units across products)
      ExcelColumnDef<AdminStockHolderRow>(
        key: 'total_custody',
        label: 'Total Custody',
        group: products.isNotEmpty ? 'VALUATION & AUDIT' : null,
        defaultWidth: 120,
        minWidth: 100,
        align: TextAlign.center,
        sortValue: (row) => row.totalUnits,
        cellBuilder: (ctx, row, idx, dark, primary) {
          final hasStock = row.totalUnits > 0;
          return Center(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: hasStock
                    ? (row.isDcShelf
                        ? const Color(0xFF10B981).withValues(alpha: 0.15)
                        : const Color(0xFFF97316).withValues(alpha: 0.15))
                    : (dark
                        ? const Color(0xFF1E293B)
                        : const Color(0xFFF1F5F9)),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${row.totalUnits} units',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: hasStock
                      ? (row.isDcShelf
                          ? const Color(0xFF059669)
                          : const Color(0xFFC2410C))
                      : (dark
                          ? const Color(0xFF64748B)
                          : const Color(0xFF94A3B8)),
                ),
              ),
            ),
          );
        },
      ),

      // 7. STOCK VALUATION (₦)
      ExcelColumnDef<AdminStockHolderRow>(
        key: 'total_valuation',
        label: 'Stock Value (₦)',
        group: products.isNotEmpty ? 'VALUATION & AUDIT' : null,
        defaultWidth: 140,
        minWidth: 110,
        align: TextAlign.right,
        sortValue: (row) => row.totalValueNaira,
        cellBuilder: (ctx, row, idx, dark, primary) {
          final hasStock = row.totalValueNaira > 0;
          return Align(
            alignment: Alignment.centerRight,
            child: Text(
              CurrencyFormatter.formatNaira(row.totalValueNaira),
              style: GoogleFonts.jetBrainsMono(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: hasStock
                    ? (dark ? Colors.white : const Color(0xFF0F172A))
                    : const Color(0xFF94A3B8),
              ),
            ),
          );
        },
      ),

      // 8. ACTIONS
      ExcelColumnDef<AdminStockHolderRow>(
        key: 'actions',
        label: 'Actions',
        defaultWidth: 120,
        minWidth: 100,
        cellBuilder: (ctx, row, idx, dark, primary) {
          return Align(
            alignment: Alignment.centerLeft,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.tune_rounded,
                        size: 18, color: Color(0xFF0284C7)),
                    tooltip: 'View Held Products Breakdown for ${row.name}',
                    onPressed: () {
                      _showHolderBreakdownDialog(
                          context, row, products, dark);
                    },
                  ),
                  if (!row.isDcShelf && row.agentRef != null) ...[
                    IconButton(
                      icon: const Icon(Icons.point_of_sale_rounded,
                          size: 18, color: Color(0xFF059669)),
                      tooltip: 'Log Daily Sales & Balance Stock for ${row.name}',
                      onPressed: () {
                        AdminLogDailySaleModal.show(
                          context: context,
                          initialAgent: row.agentRef!,
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.inventory_2_outlined,
                          size: 18, color: Color(0xFFF97316)),
                      tooltip: 'Adjust / Manage Stock Custody for ${row.name}',
                      onPressed: () {
                        AdminManageAgentCustodyModal.show(
                          context: context,
                          agent: row.agentRef!,
                          catalogProducts: products,
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined,
                          size: 18, color: Color(0xFF10B981)),
                      tooltip: 'Edit Agent, Fees & Merchant Assignment',
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (c) => AdminEditAgentModal(
                            agent: row.agentRef!,
                            availableMerchants: merchants,
                            onSave: (updatedAgent) {
                              ref.read(adminConsoleProvider.notifier).updateLogisticsAgent(updatedAgent);
                            },
                          ),
                        );
                      },
                    ),
                  ],
                  if (row.isDcShelf)
                    IconButton(
                      icon: const Icon(Icons.verified_outlined,
                          size: 18, color: Color(0xFF10B981)),
                      tooltip: 'Inbound Batch QC & Physical Restock',
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (c) => const AdminInboundQCModal(),
                        );
                      },
                    ),
                ],
              ),
            ),
          );
        },
      ),
    ];

    final topToolbarActions = <Widget>[
      // 1. Merchant Filter
      Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.storefront_outlined,
                size: 13,
                color: isDark
                    ? const Color(0xFF94A3B8)
                    : const Color(0xFF64748B)),
            const SizedBox(width: 6),
            DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: state.stockMerchantFilter,
                isDense: true,
                dropdownColor:
                    isDark ? const Color(0xFF1E293B) : Colors.white,
                style: GoogleFonts.inter(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF0F172A)),
                items: [
                  const DropdownMenuItem(
                      value: 'all', child: Text('All Merchants')),
                  ...merchants.map((m) => DropdownMenuItem(
                        value: m.id,
                        child: Text(m.businessName),
                      )),
                ],
                onChanged: (val) {
                  if (val != null) notifier.setStockMerchantFilter(val);
                },
              ),
            ),
          ],
        ),
      ),

      // 2. DC Hub Filter
      Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.hub_outlined,
                size: 13,
                color: isDark
                    ? const Color(0xFF94A3B8)
                    : const Color(0xFF64748B)),
            const SizedBox(width: 6),
            DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: state.stockHubFilter,
                isDense: true,
                dropdownColor:
                    isDark ? const Color(0xFF1E293B) : Colors.white,
                style: GoogleFonts.inter(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF0F172A)),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All DC Hubs')),
                  DropdownMenuItem(value: 'Abuja', child: Text('Abuja Central DC')),
                  DropdownMenuItem(value: 'Lagos', child: Text('Lagos Central DC')),
                ],
                onChanged: (val) {
                  if (val != null) notifier.setStockHubFilter(val);
                },
              ),
            ),
          ],
        ),
      ),

      // 3. Custodian & Health Filter
      Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.shield_outlined,
                size: 13,
                color: isDark
                    ? const Color(0xFF94A3B8)
                    : const Color(0xFF64748B)),
            const SizedBox(width: 6),
            DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: state.stockHealthFilter,
                isDense: true,
                dropdownColor:
                    isDark ? const Color(0xFF1E293B) : Colors.white,
                style: GoogleFonts.inter(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF0F172A)),
                items: [
                  DropdownMenuItem(
                      value: 'all',
                      child: Text('All Custodians ($totalHoldersCount)')),
                  const DropdownMenuItem(
                      value: 'dc_shelves_only',
                      child: Text('Warehouse Shelves (2)')),
                  DropdownMenuItem(
                      value: 'agents_only',
                      child: Text(
                          'Agent Fleet (${(totalHoldersCount - 2).clamp(0, 9999)})')),
                  const DropdownMenuItem(
                      value: 'in_stock', child: Text('In Stock (> 0)')),
                  const DropdownMenuItem(
                      value: 'zero_stock', child: Text('Zero Stock (0)')),
                ],
                onChanged: (val) {
                  if (val != null) notifier.setStockHealthFilter(val);
                },
              ),
            ),
          ],
        ),
      ),

      // 4. Compact Search Box
      SizedBox(
        width: 180,
        height: 32,
        child: TextField(
          onChanged: notifier.setSearchQuery,
          style: GoogleFonts.inter(fontSize: 11.5),
          decoration: InputDecoration(
            hintText: 'Search Agent, Code, DC...',
            hintStyle: GoogleFonts.inter(
                fontSize: 11, color: const Color(0xFF94A3B8)),
            prefixIcon: const Icon(Icons.search_rounded,
                size: 14, color: Color(0xFF64748B)),
            prefixIconConstraints:
                const BoxConstraints(minWidth: 26, minHeight: 26),
            filled: true,
            fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(
                  color: isDark
                      ? const Color(0xFF334155)
                      : const Color(0xFFCBD5E1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(
                  color: isDark
                      ? const Color(0xFF334155)
                      : const Color(0xFFCBD5E1)),
            ),
          ),
        ),
      ),

      // 5. Log Daily Sales Button
      ElevatedButton.icon(
        icon: const Icon(Icons.point_of_sale_rounded, size: 13),
        label: const Text('Log Daily Sales'),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF059669),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
          minimumSize: const Size(0, 32),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          textStyle:
              GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold),
        ),
        onPressed: () {
          AdminLogDailySaleModal.show(context: context);
        },
      ),

      // 6. Inbound Batch & QC Button
      ElevatedButton.icon(
        icon: const Icon(Icons.verified_outlined, size: 13),
        label: const Text('Inbound QC'),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0284C7),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
          minimumSize: const Size(0, 32),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          textStyle:
              GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold),
        ),
        onPressed: () {
          showDialog(
            context: context,
            builder: (ctx) => const AdminInboundQCModal(),
          );
        },
      ),

      // 6. Onboard Product Button
      ElevatedButton.icon(
        icon: const Icon(Icons.add_box_outlined, size: 13),
        label: const Text('Onboard Product'),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF10B981),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
          minimumSize: const Size(0, 32),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          textStyle:
              GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold),
        ),
        onPressed: () {
          showDialog(
            context: context,
            builder: (ctx) => const AdminOnboardProductModal(),
          );
        },
      ),

      // 7. Manage Products (Edit & Delete)
      ElevatedButton.icon(
        icon: const Icon(Icons.settings_suggest_outlined, size: 13),
        label: const Text('Manage Products'),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF3B82F6),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
          minimumSize: const Size(0, 32),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          textStyle:
              GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold),
        ),
        onPressed: () {
          AdminManageProductsModal.show(context: context);
        },
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
      ),
      child: PangeaExcelDataTable<AdminStockHolderRow>(
        items: holders,
        columns: columns,
        brandPrimary: const Color(0xFF0284C7),
        tableHeight: 660,
        initialPageSize: 15,
        topToolbarActions: topToolbarActions,
        onRowTap: (row) {
          AdminStockHolderDetailModal.show(
            context: context,
            holder: row,
            allProducts: products,
            onInboundQc: () {
              showDialog(
                context: context,
                builder: (c) => const AdminInboundQCModal(),
              );
            },
            onOnboardProduct: () {
              showDialog(
                context: context,
                builder: (c) => const AdminOnboardProductModal(),
              );
            },
            onManageCustody: row.agentRef != null
                ? () {
                    AdminManageAgentCustodyModal.show(
                      context: context,
                      agent: row.agentRef!,
                      catalogProducts: products,
                    );
                  }
                : null,
            onEditAgent: row.agentRef != null
                ? () {
                    showDialog(
                      context: context,
                      builder: (c) => AdminEditAgentModal(
                        agent: row.agentRef!,
                        availableMerchants: merchants,
                        onSave: (updatedAgent) {
                          notifier.updateLogisticsAgent(updatedAgent);
                        },
                      ),
                    );
                  }
                : null,
          );
        },
        emptyMessage:
            'No agents or distribution shelves match the selected filter criteria.',
      ),
    );
  }

  Widget _buildMobileStockCardList(
    BuildContext context,
    WidgetRef ref,
    List<AdminStockHolderRow> holders,
    List<AdminGlobalStockItem> products,
    List<AdminMerchant> merchants,
    bool isDark,
  ) {
    if (holders.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Text(
            'No agents or distribution shelves match the active filters.',
            style: GoogleFonts.inter(color: const Color(0xFF64748B)),
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: holders.length,
      separatorBuilder: (ctx, idx) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final row = holders[index];
        final hasStock = row.totalUnits > 0;

        IconData icon;
        Color iconColor;
        if (row.isDcShelf) {
          icon = Icons.warehouse_rounded;
          iconColor = const Color(0xFF10B981);
        } else if (row.isInternalFleet) {
          icon = Icons.local_shipping_rounded;
          iconColor = const Color(0xFFEA580C);
        } else {
          icon = Icons.delivery_dining_rounded;
          iconColor = const Color(0xFF0284C7);
        }

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: isDark
                    ? const Color(0xFF1E293B)
                    : const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, size: 18, color: iconColor),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(row.name,
                            style: GoogleFonts.inter(
                                fontSize: 13.5, fontWeight: FontWeight.bold)),
                        Text('${row.code} • ${row.hubName} • ${row.typeLabel}',
                            style: GoogleFonts.inter(
                                fontSize: 11,
                                color: const Color(0xFF64748B))),
                      ],
                    ),
                  ),
                  Text('${row.totalUnits} units',
                      style: GoogleFonts.jetBrainsMono(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: hasStock
                              ? (row.isDcShelf
                                  ? const Color(0xFF059669)
                                  : const Color(0xFFC2410C))
                              : const Color(0xFF94A3B8))),
                ],
              ),
              const SizedBox(height: 12),

              // Product chips
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: products.map((p) {
                  final qty = row.quantityForSku(p.sku);
                  return _chip(
                    '${_shortProductName(p.productName)}: $qty',
                    qty > 0
                        ? (row.isDcShelf
                            ? const Color(0xFF10B981)
                            : (row.isInternalFleet
                                ? const Color(0xFFEA580C)
                                : const Color(0xFF0284C7)))
                        : const Color(0xFF94A3B8),
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),

              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 6,
                children: [
                  Text(
                    'Value: ${CurrencyFormatter.formatNaira(row.totalValueNaira)}',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  Wrap(
                    spacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      TextButton.icon(
                        icon: const Icon(Icons.tune_rounded, size: 14),
                        label: const Text('Breakdown'),
                        onPressed: () => _showHolderBreakdownDialog(
                            context, row, products, isDark),
                      ),
                      if (!row.isDcShelf && row.agentRef != null) ...[
                        TextButton.icon(
                          icon: const Icon(Icons.inventory_2_outlined, size: 14),
                          label: const Text('Custody'),
                          style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFFF97316)),
                          onPressed: () {
                            AdminManageAgentCustodyModal.show(
                              context: context,
                              agent: row.agentRef!,
                              catalogProducts: products,
                            );
                          },
                        ),
                        TextButton.icon(
                          icon: const Icon(Icons.edit_outlined, size: 14),
                          label: const Text('Edit'),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (c) => AdminEditAgentModal(
                                agent: row.agentRef!,
                                availableMerchants: merchants,
                                onSave: (updatedAgent) {
                                  ref
                                      .read(adminConsoleProvider.notifier)
                                      .updateLogisticsAgent(updatedAgent);
                                },
                              ),
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  static String _shortProductName(String fullName) {
    if (fullName.contains('Grazer')) return 'Grazer Tea';
    if (fullName.contains('Respira')) return 'Respira Tea';
    if (fullName.contains('Ura Clear')) return 'Ura Clear';
    if (fullName.contains('Shampoo')) return 'Hair Shampoo';
    if (fullName.contains('Compression') || fullName.contains('vest')) {
      return 'Compress Vest';
    }
    final words = fullName.split(' ');
    return words.take(2).join(' ');
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: GoogleFonts.jetBrainsMono(
            fontSize: 11, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }

  void _showHolderBreakdownDialog(
    BuildContext context,
    AdminStockHolderRow row,
    List<AdminGlobalStockItem> products,
    bool isDark,
  ) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
          title: Row(
            children: [
              Icon(
                row.isDcShelf
                    ? Icons.warehouse_rounded
                    : Icons.local_shipping_outlined,
                color: const Color(0xFF0284C7),
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text('${row.name} Custody Breakdown',
                    style: GoogleFonts.inter(
                        fontSize: 14, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Operating Hub: ${row.hubName} (${row.code})',
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF64748B)),
                ),
                if (row.assignedMerchantNames.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Merchants: ${row.assignedMerchantNames.join(", ")}',
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF7C3AED)),
                  ),
                ],
                const Divider(height: 20),
                Text('Products in Physical Custody:',
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold, fontSize: 12.5)),
                const SizedBox(height: 8),
                ...products.map((p) {
                  final qty = row.quantityForSku(p.sku);
                  final val = qty * p.unitPrice;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '• ${p.productName}',
                            style: GoogleFonts.inter(fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '$qty units (${CurrencyFormatter.formatNaira(val)})',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: qty > 0
                                ? (row.isDcShelf
                                    ? const Color(0xFF059669)
                                    : const Color(0xFFEA580C))
                                : const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                const Divider(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total Physical Custody:',
                        style: GoogleFonts.inter(
                            fontWeight: FontWeight.bold, fontSize: 13)),
                    Text(
                      '${row.totalUnits} units',
                      style: GoogleFonts.jetBrainsMono(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: const Color(0xFF0284C7)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total Valuation:',
                        style: GoogleFonts.inter(
                            fontWeight: FontWeight.bold, fontSize: 13)),
                    Text(
                      CurrencyFormatter.formatNaira(row.totalValueNaira),
                      style: GoogleFonts.jetBrainsMono(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: const Color(0xFF059669)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close')),
          ],
        );
      },
    );
  }

  InputDecoration _filterInputDeco(String label, IconData icon, bool isDark) {
    return InputDecoration(
      labelText: label,
      labelStyle:
          GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
      prefixIcon: Icon(icon, size: 16, color: const Color(0xFF64748B)),
      filled: true,
      fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
      ),
    );
  }
}
