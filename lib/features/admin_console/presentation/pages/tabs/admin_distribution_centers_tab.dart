import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../core/helpers/formatters.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/widgets/nova_critical_action_confirmation_modal.dart';
import '../../../../../core/widgets/nova_tooltip.dart';
import '../../../../auth/presentation/providers/auth_provider.dart';
import '../../../../client_portal/presentation/widgets/pangea_excel_data_table.dart';
import '../../../domain/entities/admin_models.dart';
import '../../providers/admin_console_provider.dart';
import '../../widgets/admin_dc_modal.dart';
import '../../widgets/admin_metric_card.dart';
import '../../widgets/admin_warehouse_detail_modal.dart';

class AdminDistributionCentersTab extends ConsumerWidget {
  const AdminDistributionCentersTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(adminConsoleProvider);
    final notifier = ref.read(adminConsoleProvider.notifier);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Filter to the 2 official autonomous DCs (Abuja Central DC & Lagos Central DC)
    // Strictly filtering out any legacy dummy/test records (Benue, Lokoja, etc.)
    final dcs = state.filteredDistributionCenters.where((dc) {
      final code = dc.code.toLowerCase();
      final name = dc.name.toLowerCase();
      return !code.contains('bnu') &&
          !code.contains('lkj') &&
          !name.contains('benue') &&
          !name.contains('lokoja');
    }).toList();

    final totalDcs = dcs.length;
    final totalRiders = dcs.fold(0, (s, d) => s + d.activeRiders);
    final totalVaultNaira = dcs.fold(0.0, (s, d) => s + d.vaultBalance);
    final totalStock = dcs.fold(0, (s, d) => s + d.currentStockCount);

    // Columns definition for PangeaExcelDataTable
    final columns = <ExcelColumnDef<AdminDistributionCenter>>[
      // 1. Distribution Center & Code
      ExcelColumnDef<AdminDistributionCenter>(
        key: 'dc',
        label: 'Distribution Center',
        defaultWidth: 260,
        minWidth: 210,
        sortValue: (dc) => dc.name,
        searchString: (dc) => '${dc.name} ${dc.code} ${dc.address}',
        cellBuilder: (ctx, dc, idx, dark, primary) {
          final isAbuja = dc.code.contains('ABJ') || dc.code.contains('CMD') || dc.name.toLowerCase().contains('abuja');
          return Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: dc.isGrandDc
                      ? AppColors.orange.withValues(alpha: 0.15)
                      : const Color(0xFF0284C7).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  dc.code,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: dc.isGrandDc ? AppColors.orange : const Color(0xFF0284C7),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            dc.name,
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: dark ? Colors.white : const Color(0xFF0F172A),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (dc.isGrandDc) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.stars_rounded, size: 14, color: AppColors.orange),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      dc.address,
                      style: GoogleFonts.inter(
                        fontSize: 10.5,
                        color: const Color(0xFF64748B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),

      // 2. Region / State
      ExcelColumnDef<AdminDistributionCenter>(
        key: 'region',
        label: 'Region / State',
        defaultWidth: 150,
        minWidth: 120,
        sortValue: (dc) => dc.state,
        searchString: (dc) => '${dc.city} ${dc.state}',
        cellBuilder: (ctx, dc, idx, dark, primary) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                dc.city,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: dark ? Colors.white : const Color(0xFF0F172A),
                ),
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                dc.state,
                style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF64748B)),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          );
        },
      ),

      // 3. Working Agents
      ExcelColumnDef<AdminDistributionCenter>(
        key: 'agents',
        label: 'Working Logistics Agents',
        defaultWidth: 230,
        minWidth: 180,
        cellBuilder: (ctx, dc, idx, dark, primary) {
          final isAbuja = dc.code.contains('ABJ') || dc.code.contains('CMD') || dc.name.toLowerCase().contains('abuja');
          return Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              if (isAbuja)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    'NovaXpress Logistics',
                    style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF0284C7)),
                  ),
                ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                ),
                child: Text(
                  isAbuja ? '48 Northern Agents' : '65 Southern Agents',
                  style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF059669)),
                ),
              ),
            ],
          );
        },
      ),

      // 4. Lead Supervisor (Admin Ops)
      ExcelColumnDef<AdminDistributionCenter>(
        key: 'supervisor',
        label: 'Station Head (Admin Ops)',
        defaultWidth: 170,
        minWidth: 130,
        sortValue: (dc) => dc.supervisorName,
        cellBuilder: (ctx, dc, idx, dark, primary) {
          return Row(
            children: [
              const Icon(Icons.person_outline_rounded, size: 14, color: Color(0xFF64748B)),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  dc.supervisorName,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: dark ? Colors.white : const Color(0xFF0F172A),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          );
        },
      ),

      // 5. Active Fleet (Dispatch Ops)
      ExcelColumnDef<AdminDistributionCenter>(
        key: 'fleet',
        label: 'Active Fleet (Dispatch Ops)',
        defaultWidth: 150,
        minWidth: 110,
        sortValue: (dc) => dc.activeRiders,
        cellBuilder: (ctx, dc, idx, dark, primary) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.two_wheeler_outlined, size: 15, color: Color(0xFF64748B)),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  '${dc.activeRiders} Riders',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: dark ? Colors.white : const Color(0xFF0F172A),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          );
        },
      ),

      // 6. Vault Cash (Account Ops)
      ExcelColumnDef<AdminDistributionCenter>(
        key: 'vault',
        label: 'Vault Cash (Account Ops)',
        defaultWidth: 160,
        minWidth: 120,
        sortValue: (dc) => dc.vaultBalance,
        cellBuilder: (ctx, dc, idx, dark, primary) {
          return Text(
            CurrencyFormatter.formatNaira(dc.vaultBalance),
            style: GoogleFonts.jetBrainsMono(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF10B981),
            ),
          );
        },
      ),

      // 7. Shelf Stock & Capacity (Stock Ops)
      ExcelColumnDef<AdminDistributionCenter>(
        key: 'capacity',
        label: 'Shelf Capacity (Stock Ops)',
        defaultWidth: 160,
        minWidth: 120,
        sortValue: (dc) => dc.currentStockCount,
        cellBuilder: (ctx, dc, idx, dark, primary) {
          final pct = (dc.capacity > 0 ? (dc.currentStockCount / dc.capacity) : 0.0).clamp(0.0, 1.0);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${dc.currentStockCount} / ${dc.capacity} units',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: dark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 3),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: pct,
                  minHeight: 4,
                  backgroundColor: dark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    pct > 0.85 ? const Color(0xFFEF4444) : const Color(0xFF0284C7),
                  ),
                ),
              ),
            ],
          );
        },
      ),

      // 8. Actions
      ExcelColumnDef<AdminDistributionCenter>(
        key: 'actions',
        label: 'Actions',
        defaultWidth: 90,
        minWidth: 70,
        cellBuilder: (ctx, dc, idx, dark, primary) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 16, color: Color(0xFF0284C7)),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                tooltip: 'Edit Distribution Center',
                onPressed: () => _openDCModal(context, ref, dc),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFEF4444)),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                tooltip: 'Decommission Distribution Center',
                onPressed: () async {
                  final currentUser = ref.read(authProvider).user;
                  final confirmed = await NovaCriticalActionConfirmationModal.show(
                    context: context,
                    actionName: 'Decommission Distribution Center Hub',
                    isDestructive: true,
                    operatorAccount: currentUser?.email ?? 'operations@novaxpress.ng',
                    promptMessage:
                        'Are you sure you want to permanently decommission this Distribution Center from active database operations?',
                    valuesets: {
                      'Hub Name': dc.name,
                      'Station Code': dc.code,
                      'Location': '${dc.city}, ${dc.state}',
                      'Active Couriers': '${dc.activeRiders} riders',
                      'Current Shelf Stock': '${dc.currentStockCount} units',
                    },
                  );
                  if (confirmed) {
                    final ok = await notifier.deleteDistributionCenter(dc.id);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            ok
                                ? 'Distribution Center ${dc.name} (${dc.code}) decommissioned.'
                                : 'Decommissioned locally; database sync logged.',
                          ),
                          backgroundColor: const Color(0xFFEF4444),
                        ),
                      );
                    }
                  }
                },
              ),
            ],
          );
        },
      ),
    ];

    // Top Toolbar Actions beside Settings Button
    final topToolbarActions = <Widget>[
      // 1. Search Box
      SizedBox(
        width: 250,
        height: 32,
        child: TextField(
          onChanged: notifier.setSearchQuery,
          style: GoogleFonts.inter(fontSize: 11.5),
          decoration: InputDecoration(
            hintText: 'Search DC by name, code, state...',
            hintStyle: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
            prefixIcon: const Icon(Icons.search_rounded, size: 14, color: Color(0xFF64748B)),
            prefixIconConstraints: const BoxConstraints(minWidth: 26, minHeight: 26),
            filled: true,
            fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
            ),
          ),
        ),
      ),

      // 2. Create DC Button
      ElevatedButton.icon(
        icon: const Icon(Icons.add_business_rounded, size: 13),
        label: const Text('Create DC'),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0284C7),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
          minimumSize: const Size(0, 32),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          textStyle: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold),
        ),
        onPressed: () => _openDCModal(context, ref),
      ),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Sleek, high-density Metrics Header (Compact ribbon by default)
          AdminMetricsHeader(
            metrics: [
              AdminMetricData(
                title: 'Active Hubs',
                value: '$totalDcs',
                icon: Icons.hub_outlined,
                iconColor: const Color(0xFF0284C7),
                subtitle: 'autonomous regional DCs',
                tooltip: 'Official operating distribution centers (Abuja Central DC & Lagos Central DC)',
              ),
              AdminMetricData(
                title: 'Fleet Size',
                value: '$totalRiders',
                icon: Icons.two_wheeler_outlined,
                iconColor: AppColors.orange,
                subtitle: 'allocated dispatch riders',
                tooltip: 'Combined field couriers across Abuja & Lagos distribution hubs',
              ),
              AdminMetricData(
                title: 'Vault Cash',
                value: CurrencyFormatter.formatNaira(totalVaultNaira),
                icon: Icons.account_balance_wallet_outlined,
                iconColor: const Color(0xFF10B981),
                subtitle: 'pending bank remittance',
                tooltip: 'Cash collected by riders awaiting daily settlement deposit into DC bank accounts',
              ),
              AdminMetricData(
                title: 'Vault Stock',
                value: '$totalStock units',
                icon: Icons.inventory_2_outlined,
                iconColor: const Color(0xFF8B5CF6),
                subtitle: 'stored merchant inventory',
                tooltip: 'Physical stock held across Abuja and Lagos warehouse staging shelves',
              ),
            ],
          ),
          const SizedBox(height: 10),

          // NovaXpress Logistics DC Autonomy Banner (Compact)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF0284C7).withValues(alpha: isDark ? 0.12 : 0.06),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: Color(0xFF0284C7), size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'NovaXpress Logistics Operations: Abuja Central DC and Lagos Central DC operate as two autonomous hub stations. Each DC independently administers its Admin Ops, Dispatch Ops, Stock Ops, and Account Ops — managing local warehouse inventory, assigned logistics agents, merchant consignments, and rider cash collections.',
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      height: 1.35,
                      color: isDark ? const Color(0xFFBAE6FD) : const Color(0xFF0369A1),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // High Density Excel Data Table with Filters & Actions directly on Header Beside Settings
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
            ),
            child: PangeaExcelDataTable<AdminDistributionCenter>(
              items: dcs,
              columns: columns,
              brandPrimary: const Color(0xFF0284C7),
              tableHeight: 450,
              initialPageSize: 15,
              showSettingsButton: true,
              topToolbarActions: topToolbarActions,
              onRowTap: (dc) {
                AdminWarehouseDetailModal.show(
                  context: context,
                  dc: dc,
                  onEditDc: () => _openDCModal(context, ref, dc),
                  onInboundRestock: () {
                    notifier.setActiveTab(1); // Jump to Multi-Hub Stock tab
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _openDCModal(BuildContext context, WidgetRef ref, [AdminDistributionCenter? dc]) {
    final notifier = ref.read(adminConsoleProvider.notifier);
    showDialog(
      context: context,
      builder: (context) {
        return AdminDCModal(
          initialDc: dc,
          onSave: notifier.saveDistributionCenter,
        );
      },
    );
  }
}
