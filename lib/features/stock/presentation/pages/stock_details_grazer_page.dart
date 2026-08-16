import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_logo_widget.dart';
import '../../../../core/widgets/app_skeleton_loader.dart';
import '../../domain/entities/stock_item.dart';
import '../providers/stock_provider.dart';

class StockDetailsGrazerPage extends ConsumerWidget {
  final String productName;

  const StockDetailsGrazerPage({
    super.key,
    this.productName = 'Grazer Herbal Tea',
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final stockState = ref.watch(stockProvider);

    // Safe loop lookup matching product name from database state
    StockItemEntity? matchedItem;
    for (final item in stockState.stockItems) {
      if (item.name.toLowerCase() == productName.toLowerCase()) {
        matchedItem = item;
        break;
      }
    }
    final item = matchedItem ?? (stockState.stockItems.isNotEmpty ? stockState.stockItems.first : null);

    final String displayName = item?.name ?? productName;
    final String displaySku = item?.sku ?? 'SKU: GRAZER-001';
    final String displayDesc = (item != null && item.description.isNotEmpty)
        ? item.description
        : 'Premium organic herbal tea blend formulated for colon detox and digestive health. Store in cool, dry conditions.';
    final int heldCount = item?.quantityHeld ?? 20;
    final int availableCount = item?.availableCount ?? 8;
    final int allocatedCount = item?.allocatedCount ?? 12;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0.5,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: theme.colorScheme.onSurface),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'STOCK DETAILS',
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        centerTitle: true,
        actions: [
          const Padding(
            padding: EdgeInsets.only(right: 16),
            child: AppLogoWidget(
              variant: AppLogoVariant.landscape,
              height: 24,
            ),
          ),
        ],
      ),
      body: stockState.isLoading
          ? const Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  AppSkeletonLoader(width: double.infinity, height: 140, borderRadius: 16),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: AppSkeletonLoader(width: double.infinity, height: 90, borderRadius: 16)),
                      SizedBox(width: 12),
                      Expanded(child: AppSkeletonLoader(width: double.infinity, height: 90, borderRadius: 16)),
                    ],
                  ),
                  SizedBox(height: 16),
                  AppSkeletonLoader(width: double.infinity, height: 80, borderRadius: 16),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product Header Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.15)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    displaySku.toUpperCase(),
                                    style: GoogleFonts.jetBrainsMono(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.onSurfaceVariant,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    displayName,
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.orange.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.eco_rounded, color: AppColors.orange, size: 24),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          displayDesc,
                          style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Inventory Stats Grid
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: theme.cardColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.15)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'TOTAL HELD',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(
                                    '$heldCount',
                                    style: GoogleFonts.inter(
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Units',
                                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: theme.cardColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.primary, width: 2),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'AVAILABLE',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(
                                    '$availableCount',
                                    style: GoogleFonts.inter(
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.orange,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Units',
                                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Allocated Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.15)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceContainer,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.pending_actions_rounded, color: AppColors.orange, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'ALLOCATED TO ORDERS',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                Text(
                                  'Assigned for dispatch',
                                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Text(
                          '$allocatedCount Units',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Recent Movements Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Recent Movements',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        'FILTER',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  Container(
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.15)),
                    ),
                    child: Column(
                      children: [
                        ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Color(0xFFFFDAD6),
                            child: Icon(Icons.arrow_upward_rounded, color: Color(0xFFBA1A1A), size: 20),
                          ),
                          title: Text(
                            'Issued for Order #NEX-8821',
                            style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
                          ),
                          subtitle: Text('Today, 08:45 AM', style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
                          trailing: Text(
                            '-$allocatedCount Units',
                            style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold, color: const Color(0xFFBA1A1A), fontSize: 15),
                          ),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Color(0xFF9EF6B6),
                            child: Icon(Icons.arrow_downward_rounded, color: Color(0xFF00522A), size: 20),
                          ),
                          title: Text(
                            'Received from DC Warehouse',
                            style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
                          ),
                          subtitle: Text('Yesterday, 16:30 PM', style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
                          trailing: Text(
                            '+$heldCount Units',
                            style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold, color: const Color(0xFF00522A), fontSize: 15),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
