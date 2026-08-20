import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_skeleton_loader.dart';
import '../providers/stock_provider.dart';

class StockHistoryPage extends ConsumerStatefulWidget {
  const StockHistoryPage({super.key});

  @override
  ConsumerState<StockHistoryPage> createState() => _StockHistoryPageState();
}

class _StockHistoryPageState extends ConsumerState<StockHistoryPage> {
  String _selectedFilter = 'All';

  final List<String> _filters = [
    'All',
    'Received',
    'Delivered',
    'Returned',
    'Damaged',
    'Adjusted',
  ];

  final List<Map<String, dynamic>> _movements = [
    {
      'type': 'RECEIVED',
      'category': 'Received',
      'productName': 'Respira Detox Tea',
      'quantityText': '+10 Units',
      'isPositive': true,
      'source': 'Wuse Distribution Center',
      'reference': 'STK-00482',
      'timestamp': 'Today • 10:42 AM',
      'badgeColor': const Color(0xFF16A34A),
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
      'badgeColor': const Color(0xFFE11D48),
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
      'badgeColor': const Color(0xFFEA580C),
      'icon': Icons.replay_rounded,
    },
    {
      'type': 'DAMAGED',
      'category': 'Damaged',
      'productName': 'Respira Detox Tea',
      'quantityText': '-1 Unit',
      'isPositive': false,
      'source': 'Package seal broken during transit',
      'reference': 'AUD-00192',
      'timestamp': 'Yesterday • 05:30 PM',
      'badgeColor': const Color(0xFF9333EA),
      'icon': Icons.broken_image_rounded,
    },
    {
      'type': 'ADJUSTMENT',
      'category': 'Adjusted',
      'productName': 'Alpha Man Organic',
      'quantityText': '+2 Units',
      'isPositive': true,
      'source': 'Hub inventory variance reconciliation',
      'reference': 'ADJ-00891',
      'timestamp': '16 Aug • 09:15 AM',
      'badgeColor': const Color(0xFF2563EB),
      'icon': Icons.tune_rounded,
    },
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final stockState = ref.watch(stockProvider);

    final filteredMovements = _selectedFilter == 'All'
        ? _movements
        : _movements.where((m) => m['category'] == _selectedFilter).toList();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: theme.colorScheme.onSurface),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Inventory History',
          style: GoogleFonts.inter(
            color: theme.colorScheme.onSurface,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Daily Movement Summary Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "TODAY'S STOCK SUMMARY",
                    style: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const _StatColumn(label: 'Received', value: '+30', color: Color(0xFF4ADE80)),
                      const _StatColumn(label: 'Delivered', value: '-15', color: Color(0xFFF87171)),
                      const _StatColumn(label: 'Returned', value: '-2', color: Color(0xFFFB923C)),
                      _StatColumn(label: 'Current Custody', value: '${stockState.totalInCustody}', color: Colors.white),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Filter Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _filters.map((filter) {
                  final isSelected = _selectedFilter == filter;
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
                        if (val) setState(() => _selectedFilter = filter);
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
                    'No movements recorded for "$_selectedFilter"',
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
                                      fontWeight: FontWeight.bold,
                                      color: m['badgeColor'] as Color,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                  Text(
                                    m['quantityText'] as String,
                                    style: GoogleFonts.jetBrainsMono(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: m['isPositive'] as bool
                                          ? const Color(0xFF16A34A)
                                          : const Color(0xFFE11D48),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                m['productName'] as String,
                                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                m['source'] as String,
                                style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Text(
                                    'Ref: ${m['reference']}',
                                    style: GoogleFonts.jetBrainsMono(fontSize: 10, color: const Color(0xFF94A3B8)),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    m['timestamp'] as String,
                                    style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
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
              }),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatColumn({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
