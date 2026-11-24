import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../core/helpers/formatters.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../client_portal/presentation/widgets/pangea_excel_data_table.dart';
import '../../../domain/entities/admin_models.dart';
import '../../providers/admin_console_provider.dart';
import '../../widgets/admin_metric_card.dart';

class AdminWarehouseExpensesTab extends ConsumerWidget {
  const AdminWarehouseExpensesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(adminConsoleProvider);
    final notifier = ref.read(adminConsoleProvider.notifier);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final expenses = state.filteredExpenses;
    final totalExpenseAmount = state.expenses.fold<double>(0.0, (s, e) => s + e.amount);
    final dieselTotal = state.expenses
        .where((e) => e.category == 'diesel_generator')
        .fold<double>(0.0, (s, e) => s + e.amount);
    final rentTotal = state.expenses
        .where((e) => e.category == 'facility_rent')
        .fold<double>(0.0, (s, e) => s + e.amount);
    final opsFleetTotal = state.expenses
        .where((e) => e.category == 'vehicle_fleet' || e.category == 'packaging_materials')
        .fold<double>(0.0, (s, e) => s + e.amount);

    // Active DCs (filtered to Abuja & Lagos)
    final dcs = state.distributionCenters.where((dc) {
      final code = dc.code.toLowerCase();
      final name = dc.name.toLowerCase();
      return !code.contains('bnu') &&
          !code.contains('lkj') &&
          !name.contains('benue') &&
          !name.contains('lokoja');
    }).toList();

    // Columns definition for PangeaExcelDataTable
    final columns = <ExcelColumnDef<AdminWarehouseExpense>>[
      // 1. Receipt #
      ExcelColumnDef<AdminWarehouseExpense>(
        key: 'receipt',
        label: 'Receipt #',
        defaultWidth: 140,
        minWidth: 110,
        sortValue: (e) => e.receiptNumber,
        searchString: (e) => e.receiptNumber,
        cellBuilder: (ctx, exp, idx, dark, primary) {
          final receipt = exp.receiptNumber.isNotEmpty ? exp.receiptNumber : '—';
          return Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: dark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: dark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
              ),
              child: Text(
                receipt,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: dark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ),
          );
        },
      ),

      // 2. Date
      ExcelColumnDef<AdminWarehouseExpense>(
        key: 'date',
        label: 'Date',
        defaultWidth: 110,
        minWidth: 90,
        sortValue: (e) => e.recordedAt.millisecondsSinceEpoch,
        cellBuilder: (ctx, exp, idx, dark, primary) {
          final dt = exp.recordedAt;
          return Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}',
              style: GoogleFonts.inter(fontSize: 11.5, color: dark ? Colors.white70 : const Color(0xFF475569)),
            ),
          );
        },
      ),

      // 3. Distribution Center
      ExcelColumnDef<AdminWarehouseExpense>(
        key: 'warehouse',
        label: 'Distribution Center',
        defaultWidth: 180,
        minWidth: 140,
        sortValue: (e) => e.warehouseName,
        searchString: (e) => e.warehouseName,
        cellBuilder: (ctx, exp, idx, dark, primary) {
          return Align(
            alignment: Alignment.centerLeft,
            child: Text(
              exp.warehouseName,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: dark ? Colors.white : const Color(0xFF0F172A),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          );
        },
      ),

      // 4. Expense Details
      ExcelColumnDef<AdminWarehouseExpense>(
        key: 'details',
        label: 'Expense Details',
        defaultWidth: 260,
        minWidth: 180,
        sortValue: (e) => e.title,
        searchString: (e) => '${e.title} ${e.notes}',
        cellBuilder: (ctx, exp, idx, dark, primary) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                exp.title,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: dark ? Colors.white : const Color(0xFF0F172A),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (exp.notes.isNotEmpty)
                Text(
                  exp.notes,
                  style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF94A3B8)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          );
        },
      ),

      // 5. Category
      ExcelColumnDef<AdminWarehouseExpense>(
        key: 'category',
        label: 'Category',
        defaultWidth: 160,
        minWidth: 120,
        sortValue: (e) => e.categoryLabel,
        cellBuilder: (ctx, exp, idx, dark, primary) {
          final catColor = _getCategoryColor(exp.category);
          return Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: catColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: catColor.withValues(alpha: 0.3)),
              ),
              child: Text(
                exp.categoryLabel,
                style: GoogleFonts.inter(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  color: catColor,
                ),
              ),
            ),
          );
        },
      ),

      // 6. Amount
      ExcelColumnDef<AdminWarehouseExpense>(
        key: 'amount',
        label: 'Amount (₦)',
        defaultWidth: 140,
        minWidth: 110,
        align: TextAlign.right,
        sortValue: (e) => e.amount,
        cellBuilder: (ctx, exp, idx, dark, primary) {
          return Align(
            alignment: Alignment.centerRight,
            child: Text(
              CurrencyFormatter.formatNaira(exp.amount),
              style: GoogleFonts.jetBrainsMono(
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
                color: const Color(0xFFEF4444),
              ),
            ),
          );
        },
      ),

      // 7. Recorded By
      ExcelColumnDef<AdminWarehouseExpense>(
        key: 'recorded_by',
        label: 'Recorded By',
        defaultWidth: 150,
        minWidth: 110,
        sortValue: (e) => e.recordedBy,
        searchString: (e) => e.recordedBy,
        cellBuilder: (ctx, exp, idx, dark, primary) {
          return Align(
            alignment: Alignment.centerLeft,
            child: Text(
              exp.recordedBy,
              style: GoogleFonts.inter(fontSize: 11.5, color: dark ? Colors.white70 : const Color(0xFF64748B)),
              overflow: TextOverflow.ellipsis,
            ),
          );
        },
      ),

      // 8. Status
      ExcelColumnDef<AdminWarehouseExpense>(
        key: 'status',
        label: 'Status',
        defaultWidth: 100,
        minWidth: 80,
        cellBuilder: (ctx, exp, idx, dark, primary) {
          return Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'APPROVED',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF10B981),
                ),
              ),
            ),
          );
        },
      ),
    ];

    // Top Toolbar Actions placed directly on Header Beside Settings
    final topToolbarActions = <Widget>[
      // 1. DC Filter Dropdown
      Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.hub_outlined, size: 13, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
            const SizedBox(width: 6),
            DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: state.expenseWarehouseFilter,
                isDense: true,
                dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                style: GoogleFonts.inter(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
                items: [
                  const DropdownMenuItem(value: 'all', child: Text('All DCs')),
                  ...dcs.map((dc) => DropdownMenuItem(
                        value: dc.id,
                        child: Text('${dc.name} (${dc.city})'),
                      )),
                ],
                onChanged: (val) {
                  if (val != null) notifier.setExpenseWarehouseFilter(val);
                },
              ),
            ),
          ],
        ),
      ),

      // 2. Category Filter Dropdown
      Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.category_outlined, size: 13, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
            const SizedBox(width: 6),
            DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: state.expenseCategoryFilter,
                isDense: true,
                dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                style: GoogleFonts.inter(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All Categories')),
                  DropdownMenuItem(value: 'diesel_generator', child: Text('Diesel & Power')),
                  DropdownMenuItem(value: 'facility_rent', child: Text('Facility & Rent')),
                  DropdownMenuItem(value: 'packaging_materials', child: Text('Packaging Boxes')),
                  DropdownMenuItem(value: 'vehicle_fleet', child: Text('Fleet & Maintenance')),
                  DropdownMenuItem(value: 'security_utilities', child: Text('Security & Utilities')),
                  DropdownMenuItem(value: 'other', child: Text('Other Overhead')),
                ],
                onChanged: (val) {
                  if (val != null) notifier.setExpenseCategoryFilter(val);
                },
              ),
            ),
          ],
        ),
      ),

      // 3. Search Box
      SizedBox(
        width: 220,
        height: 32,
        child: TextField(
          onChanged: notifier.setSearchQuery,
          style: GoogleFonts.inter(fontSize: 11.5),
          decoration: InputDecoration(
            hintText: 'Search expense, receipt...',
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

      // 4. Record Expense Button
      ElevatedButton.icon(
        icon: const Icon(Icons.add_rounded, size: 14),
        label: const Text('Record Expense'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.orange,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
          minimumSize: const Size(0, 32),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          textStyle: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold),
        ),
        onPressed: () => _openRecordExpenseModal(context, ref, dcs, isDark),
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
                title: 'Total Station Expenses',
                value: CurrencyFormatter.formatNaira(totalExpenseAmount),
                icon: Icons.account_balance_wallet_rounded,
                iconColor: const Color(0xFFEF4444),
                subtitle: 'all distribution centers',
                tooltip: 'Combined operating expenses recorded across NovaXpress distribution centers',
              ),
              AdminMetricData(
                title: 'Diesel & Generator Power',
                value: CurrencyFormatter.formatNaira(dieselTotal),
                icon: Icons.power_rounded,
                iconColor: const Color(0xFFF59E0B),
                subtitle: 'cold chain & warehouse power',
                tooltip: 'Generator fuel and power continuity costs for sorting hubs',
              ),
              AdminMetricData(
                title: 'Facility Rent & Leases',
                value: CurrencyFormatter.formatNaira(rentTotal),
                icon: Icons.warehouse_rounded,
                iconColor: const Color(0xFF3B82F6),
                subtitle: 'storage hub installments',
                tooltip: 'Warehouse floor space leasing and regional facility overheads',
              ),
              AdminMetricData(
                title: 'Fleet & Packaging',
                value: CurrencyFormatter.formatNaira(opsFleetTotal),
                icon: Icons.inventory_2_outlined,
                iconColor: const Color(0xFF10B981),
                subtitle: 'cartons, bike maintenance',
                tooltip: 'Consumables, packaging materials, and courier vehicle repairs',
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Operational Context Banner (Compact)
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
                    'Station Autonomy & Accountability: Each distribution center manages its own operational expenses directly. Central Command (Grand DC) has comprehensive oversight to audit and reconcile station expenditure alongside delivery economy.',
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
            child: PangeaExcelDataTable<AdminWarehouseExpense>(
              items: expenses,
              columns: columns,
              brandPrimary: AppColors.orange,
              tableHeight: 520,
              initialPageSize: 15,
              showSettingsButton: true,
              topToolbarActions: topToolbarActions,
            ),
          ),
        ],
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'diesel_generator':
        return const Color(0xFFF59E0B);
      case 'facility_rent':
        return const Color(0xFF3B82F6);
      case 'packaging_materials':
        return const Color(0xFF10B981);
      case 'vehicle_fleet':
        return AppColors.orange;
      case 'security_utilities':
        return const Color(0xFF8B5CF6);
      default:
        return const Color(0xFF64748B);
    }
  }

  void _openRecordExpenseModal(
    BuildContext context,
    WidgetRef ref,
    List<AdminDistributionCenter> dcs,
    bool isDark,
  ) {
    if (dcs.isEmpty) return;

    final titleController = TextEditingController();
    final amountController = TextEditingController();
    final receiptController = TextEditingController();
    final notesController = TextEditingController();
    var selectedDc = dcs.first;
    var category = 'diesel_generator';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return AlertDialog(
            backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.receipt_long_rounded, color: AppColors.orange, size: 24),
                const SizedBox(width: 10),
                Text('Record Warehouse Station Expense', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Distribution Center', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<AdminDistributionCenter>(
                      value: selectedDc,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      items: dcs.map((dc) => DropdownMenuItem(value: dc, child: Text(dc.name))).toList(),
                      onChanged: (val) {
                        if (val != null) setModalState(() => selectedDc = val);
                      },
                    ),
                    const SizedBox(height: 14),

                    Text('Expense Title / Purpose', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: titleController,
                      decoration: InputDecoration(
                        hintText: 'e.g. 500L Diesel for Central Cold Storage & Conveyors',
                        filled: true,
                        fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 14),

                    Text('Expense Category', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: category,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'diesel_generator', child: Text('Diesel & Generator Fuel')),
                        DropdownMenuItem(value: 'facility_rent', child: Text('Facility Rent / Lease Installment')),
                        DropdownMenuItem(value: 'packaging_materials', child: Text('Packaging Boxes & Tapes')),
                        DropdownMenuItem(value: 'vehicle_fleet', child: Text('Courier Fleet Repairs')),
                        DropdownMenuItem(value: 'security_utilities', child: Text('Security & Utilities')),
                        DropdownMenuItem(value: 'other', child: Text('Other Operational Overhead')),
                      ],
                      onChanged: (val) {
                        if (val != null) setModalState(() => category = val);
                      },
                    ),
                    const SizedBox(height: 14),

                    Text('Amount (₦)', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: 'e.g. 450000',
                        filled: true,
                        fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 14),

                    Text('Receipt / Invoice Number', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: receiptController,
                      decoration: InputDecoration(
                        hintText: 'e.g. RCP-DSL-9021',
                        filled: true,
                        fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 14),

                    Text('Reconciliation Notes / Purpose', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: notesController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: 'e.g. Monthly fuel supply for cold room & packing lines',
                        filled: true,
                        fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.orange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () async {
                  final amount = double.tryParse(amountController.text.trim()) ?? 0.0;
                  final title = titleController.text.trim();
                  if (title.isEmpty || amount <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter a valid expense title and amount.')),
                    );
                    return;
                  }

                  Navigator.pop(ctx);
                  await ref.read(adminConsoleProvider.notifier).recordWarehouseExpense(
                        warehouseId: selectedDc.id,
                        warehouseName: selectedDc.name,
                        title: title,
                        category: category,
                        amount: amount,
                        recordedBy: 'Station Admin (${selectedDc.city})',
                        receiptNumber: receiptController.text.trim(),
                        notes: notesController.text.trim(),
                      );

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        backgroundColor: Color(0xFF16A34A),
                        content: Text('Warehouse expense recorded successfully.'),
                      ),
                    );
                  }
                },
                child: const Text('Save Expense', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }
}
