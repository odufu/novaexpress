import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_skeleton_loader.dart';
import '../providers/stock_provider.dart';

final stockHistoryFilterProvider = StateProvider.autoDispose<String>((ref) => 'All');

class StockHistoryPage extends ConsumerWidget {
  const StockHistoryPage({super.key});

  static const List<String> _filters = [
    'All',
    'Received',
    'Delivered',
    'Returned',
    'Damaged',
    'Adjusted',
  ];

  static const List<Map<String, dynamic>> _movements = [
    {
      'type': 'RECEIVED',
      'category': 'Received',
      'productName': 'Respira Detox Tea',
      'quantityText': '+10 Units',
      'isPositive': true,
      'source': 'Wuse Distribution Center',
      'reference': 'STK-00482',
      'timestamp': 'Today • 10:42 AM',
      'badgeColor': Color(0xFF16A34A),
      'icon': Icons.move_to_inbox_rounded,
    },
    {
      'type': 'DELIVERED',
      'category': 'Delivered',
      'productName': 'Respira Detox Tea',
      'quantityText': '-2 Units',
      'isPositive': false,
      'source': 'Order NX-00482 • Emeka Nwosu',
      'reference': 'NX-00482',
      'timestamp': 'Today • 02:14 PM',
      'badgeColor': Color(0xFFE11D48),
      'icon': Icons.local_shipping_rounded,
    },
    {
      'type': 'RETURNED',
      'category': 'Returned',
      'productName': 'Grazer Herbal Tea',
      'quantityText': '+1 Unit',
      'isPositive': true,
      'source': 'Order NX-00471 • Mrs. Folake Adebayo',
      'reference': 'NX-00471',
      'timestamp': 'Today • 04:02 PM',
      'badgeColor': Color(0xFFEA580C),
      'icon': Icons.replay_rounded,
    },
    {
      'type': 'DAMAGED',
      'category': 'Damaged',
      'productName': 'Respira Detox Tea',
      'quantityText': '-1 Unit',
      'isPositive': false,
      'source': 'Transit Damage Logged',
      'reference': 'AUD-00192',
      'timestamp': 'Yesterday • 06:30 PM',
      'badgeColor': Color(0xFFDC2626),
      'icon': Icons.broken_image_rounded,
    },
    {
      'type': 'ADJUSTED',
      'category': 'Adjusted',
      'productName': 'Grazer Herbal Tea',
      'quantityText': '+2 Units',
      'isPositive': true,
      'source': 'Physical Count Reconciliation',
      'reference': 'AUD-00188',
      'timestamp': '2 days ago • 11:15 AM',
      'badgeColor': Color(0xFF2563EB),
      'icon': Icons.tune_rounded,
    },
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final stockState = ref.watch(stockProvider);
    final selectedFilter = ref.watch(stockHistoryFilterProvider);

    final filteredMovements = _movements.where((m) {
      if (selectedFilter == 'All') return true;
      return (m['category'] as String).toLowerCase() == selectedFilter.toLowerCase();
    }).toList();

    final totalReceived = _movements.where((m) => m['category'] == 'Received').length;
    final totalDelivered = _movements.where((m) => m['category'] == 'Delivered').length;
    final totalReturned = _movements.where((m) => m['category'] == 'Returned').length;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Stock Movement History'),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(stockProvider.notifier).fetchStockItems();
        },
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          children: [
            // KPI Overview Banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                      : [const Color(0xFFEFF6FF), const Color(0xFFDBEAFE)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFBFDBFE),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildSummaryMetric(
                      label: 'Received',
                      count: totalReceived.toString(),
                      color: const Color(0xFF16A34A),
                      icon: Icons.south_west_rounded,
                    ),
                  ),
                  Container(width: 1, height: 36, color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                  Expanded(
                    child: _buildSummaryMetric(
                      label: 'Delivered',
                      count: totalDelivered.toString(),
                      color: const Color(0xFFE11D48),
                      icon: Icons.north_east_rounded,
                    ),
                  ),
                  Container(width: 1, height: 36, color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                  Expanded(
                    child: _buildSummaryMetric(
                      label: 'Returned',
                      count: totalReturned.toString(),
                      color: const Color(0xFFEA580C),
                      icon: Icons.replay_rounded,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Filter Chips Bar
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _filters.map((filter) {
                  final isSelected = selectedFilter == filter;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(
                        filter,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? Colors.white : theme.colorScheme.onSurface,
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: AppColors.primary,
                      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      onSelected: (val) {
                        if (val) {
                          ref.read(stockHistoryFilterProvider.notifier).state = filter;
                        }
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 20),

            // Movements Header
            Text(
              'Stock Movement Audit Log',
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Audit trail of inventory receipts, customer deliveries, DC returns, and adjustments.',
              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
            ),
            const SizedBox(height: 14),

            // Movement Audit Cards
            if (stockState.isLoading) ...[
              const AppSkeletonLoader(width: double.infinity, height: 80, borderRadius: 16),
              const SizedBox(height: 12),
              const AppSkeletonLoader(width: double.infinity, height: 80, borderRadius: 16),
            ] else if (filteredMovements.isEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Center(
                  child: Text(
                    'No movements recorded for "$selectedFilter"',
                    style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF64748B)),
                  ),
                ),
              ),
            ] else ...[
              ...filteredMovements.map((m) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: (m['badgeColor'] as Color).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(m['icon'] as IconData, color: m['badgeColor'] as Color, size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    m['type'] as String,
                                    style: GoogleFonts.jetBrainsMono(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: m['badgeColor'] as Color,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  Text(
                                    m['timestamp'] as String,
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: const Color(0xFF94A3B8),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                m['productName'] as String,
                                style: GoogleFonts.inter(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                m['source'] as String,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          m['quantityText'] as String,
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: (m['isPositive'] as bool) ? const Color(0xFF16A34A) : const Color(0xFFE11D48),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryMetric({
    required String label,
    required String count,
    required Color color,
    required IconData icon,
  }) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF64748B),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          count,
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
      ],
    );
  }
}
