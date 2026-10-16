import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:novexps/core/theme/theme_provider.dart';
import 'package:novexps/features/client_portal/data/repositories/expenditure_repository.dart';
import 'package:novexps/features/client_portal/domain/entities/business_expenditure.dart';
import 'package:novexps/features/client_portal/presentation/providers/client_portal_provider.dart';
import 'package:novexps/features/client_portal/presentation/widgets/client_add_expenditure_modal.dart';

class ClientExpensesView extends ConsumerStatefulWidget {
  const ClientExpensesView({super.key});

  @override
  ConsumerState<ClientExpensesView> createState() => _ClientExpensesViewState();
}

class _ClientExpensesViewState extends ConsumerState<ClientExpensesView> {
  final ExpenditureRepository _repo = ExpenditureRepository();
  final TextEditingController _searchController = TextEditingController();

  String? _selectedProductId; // null = all, 'generic' = non-product
  String _selectedCategory = 'all';
  String _selectedDateRange = '30d'; // 'today', '7d', '30d', 'this_month', 'all'
  DateTime? _customStartDate;
  DateTime? _customEndDate;
  String _searchQuery = '';

  bool _isLoading = true;
  List<BusinessExpenditureEntity> _allExpenditures = [];

  final currencyFormat = NumberFormat('#,##0.00', 'en_US');
  final dateFormat = DateFormat('dd MMM yyyy');

  @override
  void initState() {
    super.initState();
    _loadExpenditures();
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

  Future<void> _loadExpenditures() async {
    final state = ref.read(clientPortalProvider);
    final clientId = state.clientProfile.id;
    if (clientId.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final list = await _repo.fetchMerchantExpenditures(clientId: clientId);
      if (mounted) {
        setState(() {
          _allExpenditures = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String? _getProductName(String? productId) {
    if (productId == null || productId.isEmpty) return null;
    final products = ref.read(clientPortalProvider).products;
    for (final p in products) {
      if (p.id == productId) return p.name;
    }
    return null;
  }

  List<BusinessExpenditureEntity> _getFilteredList() {
    final now = DateTime.now();
    DateTime? start;
    DateTime? end = now;

    if (_selectedDateRange == 'today') {
      start = DateTime(now.year, now.month, now.day);
    } else if (_selectedDateRange == '7d') {
      start = now.subtract(const Duration(days: 7));
    } else if (_selectedDateRange == '30d') {
      start = now.subtract(const Duration(days: 30));
    } else if (_selectedDateRange == 'this_month') {
      start = DateTime(now.year, now.month, 1);
    } else if (_selectedDateRange == 'custom' && _customStartDate != null) {
      start = _customStartDate;
      end = _customEndDate ?? now;
    }

    return _allExpenditures.where((exp) {
      // Date filter
      if (start != null) {
        final expDate = DateTime(exp.expenditureDate.year, exp.expenditureDate.month, exp.expenditureDate.day);
        final startDateOnly = DateTime(start.year, start.month, start.day);
        if (expDate.isBefore(startDateOnly)) return false;
      }
      if (end != null) {
        final expDate = DateTime(exp.expenditureDate.year, exp.expenditureDate.month, exp.expenditureDate.day);
        final endDateOnly = DateTime(end.year, end.month, end.day, 23, 59, 59);
        if (expDate.isAfter(endDateOnly)) return false;
      }

      // Product filter
      if (_selectedProductId != null && _selectedProductId!.isNotEmpty) {
        if (_selectedProductId == 'generic') {
          if (exp.productId != null && exp.productId!.isNotEmpty) return false;
        } else {
          if (exp.productId != _selectedProductId) return false;
        }
      }

      // Category filter
      if (_selectedCategory != 'all') {
        if (exp.category.name.toLowerCase() != _selectedCategory.toLowerCase()) {
          return false;
        }
      }

      // Search query
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase().trim();
        final matchTitle = exp.title.toLowerCase().contains(q);
        final matchDesc = (exp.description ?? '').toLowerCase().contains(q);
        final matchCat = exp.category.label.toLowerCase().contains(q);
        if (!matchTitle && !matchDesc && !matchCat) return false;
      }

      return true;
    }).toList();
  }

  Future<void> _deleteExpense(BusinessExpenditureEntity exp) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Archive Expense', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Text('Are you sure you want to archive "${exp.title}" (₦${currencyFormat.format(exp.amount)})? This will remove it from active calculations.', style: GoogleFonts.inter(fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.inter(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Archive', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final ok = await _repo.deleteExpenditure(exp.id);
      if (ok) {
        setState(() {
          _allExpenditures.removeWhere((item) => item.id == exp.id);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Expense archived successfully'), backgroundColor: Color(0xFF10B981)),
          );
        }
      }
    }
  }

  void _showExpenseDetailSheet(BuildContext context, BusinessExpenditureEntity exp, bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
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
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    exp.title,
                    style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                  ),
                ),
                Text(
                  '₦${currencyFormat.format(exp.amount)}',
                  style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800, color: const Color(0xFFEF4444)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF37021).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    exp.category.label,
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFFF37021)),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  dateFormat.format(exp.expenditureDate),
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
                ),
                if (_getProductName(exp.productId) != null) ...[
                  const SizedBox(width: 8),
                  Text('• ${_getProductName(exp.productId)}', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: const Color(0xFF0D9488))),
                ],
              ],
            ),
            const Divider(height: 32),
            if (exp.description != null && exp.description!.isNotEmpty) ...[
              _buildDetailRow('Notes', exp.description!, Icons.notes_rounded, isDark),
              const SizedBox(height: 12),
            ],
            if (exp.receiptUrl != null && exp.receiptUrl!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Attached Invoice / Receipt', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
              const SizedBox(height: 8),
              InkWell(
                onTap: () => launchUrl(Uri.parse(exp.receiptUrl!)),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isDark ? Colors.white12 : Colors.grey[200]!),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.receipt_long_rounded, color: Color(0xFF0D9488), size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('View Receipt / Invoice', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF0D9488))),
                            Text('Click to open document in full resolution', style: GoogleFonts.inter(fontSize: 11, color: Colors.grey)),
                          ],
                        ),
                      ),
                      const Icon(Icons.open_in_new_rounded, size: 18, color: Colors.grey),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFEF4444),
                      side: const BorderSide(color: Color(0xFFEF4444)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _deleteExpense(exp);
                    },
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    label: Text('Archive', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFF0F172A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: Text('Done', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.grey),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: GoogleFonts.inter(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500)),
              Text(value, style: GoogleFonts.inter(fontSize: 13, color: isDark ? Colors.white : const Color(0xFF0F172A), fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
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

    final filteredList = _getFilteredList();

    // DYNAMIC METRIC RECALCULATION
    double totalSpent = 0;
    double adSpend = 0;
    double procurement = 0;
    double operating = 0;

    for (final exp in filteredList) {
      totalSpent += exp.amount;
      if (exp.category == ExpenditureCategory.advertisement) {
        adSpend += exp.amount;
      } else if (exp.category == ExpenditureCategory.procurement) {
        procurement += exp.amount;
      } else {
        operating += exp.amount;
      }
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: isMobile
          ? FloatingActionButton.extended(
              onPressed: () async {
                final created = await ClientAddExpenditureModal.show(
                  context,
                  clientId: state.clientProfile.id,
                  initialProductId: _selectedProductId == 'generic' ? null : _selectedProductId,
                );
                if (created != null) _loadExpenditures();
              },
              backgroundColor: const Color(0xFFF37021),
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: Text('Record', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white)),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _loadExpenditures,
        child: ListView(
          padding: EdgeInsets.symmetric(horizontal: isMobile ? 14 : 24, vertical: 18),
          children: [
            // 1. OPEN METRIC STRIP (Non-boxy, fluid, dynamically recalculating)
            _buildOpenMetricStrip(
              totalSpent: totalSpent,
              adSpend: adSpend,
              procurement: procurement,
              operating: operating,
              count: filteredList.length,
              isDark: isDark,
              isMobile: isMobile,
            ),
            const SizedBox(height: 20),

            // 2. INTEGRATED CONTROL BAR (Filters on Left, + Record on Right)
            _buildIntegratedControlBar(context, state, isDark, isMobile),
            const SizedBox(height: 16),

            // 3. TABLE / CARDS CONTENT
            if (_isLoading)
              const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
            else if (filteredList.isEmpty)
              _buildEmptyState(isDark)
            else if (isMobile)
              _buildMobileCardList(filteredList, isDark)
            else
              _buildDesktopTable(filteredList, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildOpenMetricStrip({
    required double totalSpent,
    required double adSpend,
    required double procurement,
    required double operating,
    required int count,
    required bool isDark,
    required bool isMobile,
  }) {
    final metrics = [
      {'label': 'Total Spent', 'value': '₦${currencyFormat.format(totalSpent)}', 'color': const Color(0xFFEF4444), 'tooltip': 'Sum of all filtered expenditures'},
      {'label': 'Ad Spend', 'value': '₦${currencyFormat.format(adSpend)}', 'color': const Color(0xFFF59E0B), 'tooltip': 'Meta, TikTok & Google marketing budget'},
      {'label': 'Procurement', 'value': '₦${currencyFormat.format(procurement)}', 'color': const Color(0xFF3B82F6), 'tooltip': 'Product inventory & manufacturing costs'},
      {'label': 'Operating', 'value': '₦${currencyFormat.format(operating)}', 'color': const Color(0xFF8B5CF6), 'tooltip': 'Airtime, packaging, utilities & general OpEx'},
    ];

    return Container(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 20, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: isMobile
          ? GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 2.2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              children: metrics.map((m) => _buildMetricItem(m, isDark)).toList(),
            )
          : Row(
              children: metrics.asMap().entries.map((entry) {
                final idx = entry.key;
                final m = entry.value;
                return Expanded(
                  child: Row(
                    children: [
                      Expanded(child: _buildMetricItem(m, isDark)),
                      if (idx < metrics.length - 1)
                        Container(height: 36, width: 1, color: isDark ? Colors.white12 : Colors.grey[200]),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _buildMetricItem(Map<String, dynamic> m, bool isDark) {
    return Tooltip(
      message: m['tooltip'] as String,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              (m['label'] as String).toUpperCase(),
              style: GoogleFonts.inter(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              m['value'] as String,
              style: GoogleFonts.inter(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIntegratedControlBar(BuildContext context, ClientPortalState state, bool isDark, bool isMobile) {
    final products = state.products;

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      alignment: WrapAlignment.spaceBetween,
      children: [
        // Left Filters
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            // Product Selector Dropdown
            Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String?>(
                  value: _selectedProductId,
                  hint: Text('All Products', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
                  items: [
                    DropdownMenuItem<String?>(
                      value: null,
                      child: Text('All Products', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                    ...products.map((p) => DropdownMenuItem<String?>(
                      value: p.id,
                      child: Text(p.name, style: GoogleFonts.inter(fontSize: 12)),
                    )),
                    DropdownMenuItem<String?>(
                      value: 'generic',
                      child: Text('General OpEx', style: GoogleFonts.inter(fontSize: 12, fontStyle: FontStyle.italic)),
                    ),
                  ],
                  onChanged: (val) => setState(() => _selectedProductId = val),
                ),
              ),
            ),

            // Date Range Dropdown
            Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedDateRange,
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
                  items: [
                    DropdownMenuItem(value: 'today', child: Text('Today', style: GoogleFonts.inter(fontSize: 12))),
                    DropdownMenuItem(value: '7d', child: Text('7 Days', style: GoogleFonts.inter(fontSize: 12))),
                    DropdownMenuItem(value: '30d', child: Text('30 Days', style: GoogleFonts.inter(fontSize: 12))),
                    DropdownMenuItem(value: 'this_month', child: Text('This Month', style: GoogleFonts.inter(fontSize: 12))),
                    DropdownMenuItem(value: 'all', child: Text('All Time', style: GoogleFonts.inter(fontSize: 12))),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedDateRange = val);
                  },
                ),
              ),
            ),

            // Search Bar
            Container(
              height: 36,
              width: isMobile ? 180 : 200,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              child: TextField(
                controller: _searchController,
                style: GoogleFonts.inter(fontSize: 12),
                decoration: const InputDecoration(
                  hintText: 'Search...',
                  prefixIcon: Icon(Icons.search_rounded, size: 16, color: Colors.grey),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
          ],
        ),

        // Right Primary Action (Desktop Only)
        if (!isMobile)
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF37021),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              final created = await ClientAddExpenditureModal.show(
                context,
                clientId: state.clientProfile.id,
                initialProductId: _selectedProductId == 'generic' ? null : _selectedProductId,
              );
              if (created != null) _loadExpenditures();
            },
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text('Record', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold)),
          ),
      ],
    );
  }

  Widget _buildDesktopTable(List<BusinessExpenditureEntity> list, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: DataTable(
          headingRowHeight: 44,
          dataRowMinHeight: 52,
          dataRowMaxHeight: 56,
          horizontalMargin: 20,
          columnSpacing: 24,
          headingRowColor: WidgetStateProperty.all(isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
          columns: [
            DataColumn(label: Text('DATE', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey))),
            DataColumn(label: Text('TITLE / VENDOR', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey))),
            DataColumn(label: Text('CATEGORY', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey))),
            DataColumn(label: Text('PRODUCT', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey))),
            DataColumn(label: Text('AMOUNT', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey))),
            DataColumn(label: Text('RECEIPT', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey))),
            DataColumn(label: Text('ACTIONS', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey))),
          ],
          rows: list.map((exp) {
            return DataRow(
              cells: [
                DataCell(Text(dateFormat.format(exp.expenditureDate), style: GoogleFonts.inter(fontSize: 12.5))),
                DataCell(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(exp.title, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                      if (exp.description != null && exp.description!.isNotEmpty)
                        Text(exp.description!, style: GoogleFonts.inter(fontSize: 11, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF37021).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(exp.category.label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFFF37021))),
                  ),
                ),
                DataCell(
                  Text(
                    _getProductName(exp.productId) ?? 'General OpEx',
                    style: GoogleFonts.inter(fontSize: 12, color: _getProductName(exp.productId) != null ? const Color(0xFF0D9488) : Colors.grey, fontWeight: FontWeight.w500),
                  ),
                ),
                DataCell(
                  Text(
                    '₦${currencyFormat.format(exp.amount)}',
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                  ),
                ),
                DataCell(
                  exp.receiptUrl != null && exp.receiptUrl!.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.attach_file_rounded, size: 18, color: Color(0xFF0D9488)),
                          tooltip: 'Open attached receipt',
                          onPressed: () => launchUrl(Uri.parse(exp.receiptUrl!)),
                        )
                      : const Text('—', style: TextStyle(color: Colors.grey)),
                ),
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.visibility_outlined, size: 18, color: Colors.grey),
                        tooltip: 'View Details',
                        onPressed: () => _showExpenseDetailSheet(context, exp, isDark),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFEF4444)),
                        tooltip: 'Archive',
                        onPressed: () => _deleteExpense(exp),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildMobileCardList(List<BusinessExpenditureEntity> list, bool isDark) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, idx) {
        final exp = list[idx];
        return InkWell(
          onTap: () => _showExpenseDetailSheet(context, exp, isDark),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        exp.title,
                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '₦${currencyFormat.format(exp.amount)}',
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: const Color(0xFFEF4444)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF37021).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(exp.category.label, style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w600, color: const Color(0xFFF37021))),
                    ),
                    const SizedBox(width: 8),
                    Text(dateFormat.format(exp.expenditureDate), style: GoogleFonts.inter(fontSize: 11, color: Colors.grey)),
                    const Spacer(),
                    if (exp.receiptUrl != null && exp.receiptUrl!.isNotEmpty)
                      const Icon(Icons.attach_file_rounded, size: 16, color: Color(0xFF0D9488)),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right_rounded, size: 18, color: Colors.grey),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(40),
      alignment: Alignment.center,
      child: Column(
        children: [
          Icon(Icons.receipt_long_outlined, size: 48, color: isDark ? Colors.white24 : Colors.grey[400]),
          const SizedBox(height: 12),
          Text('No Expenses Recorded', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('Use "+ Record" to log product marketing, procurement, or general OpEx.', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }
}
