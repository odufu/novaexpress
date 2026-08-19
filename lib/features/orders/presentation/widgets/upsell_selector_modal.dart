import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/helpers/formatters.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../stock/domain/entities/stock_item.dart';

class UpsellSelectorModal extends StatefulWidget {
  final List<StockItemEntity> availableStock;
  final Function(StockItemEntity item, double extraAmount) onUpsellSelected;

  const UpsellSelectorModal({
    super.key,
    required this.availableStock,
    required this.onUpsellSelected,
  });

  static Future<void> show({
    required BuildContext context,
    required List<StockItemEntity> availableStock,
    required Function(StockItemEntity item, double extraAmount) onUpsellSelected,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => UpsellSelectorModal(
        availableStock: availableStock,
        onUpsellSelected: onUpsellSelected,
      ),
    );
  }

  @override
  State<UpsellSelectorModal> createState() => _UpsellSelectorModalState();
}

class _UpsellSelectorModalState extends State<UpsellSelectorModal> {
  StockItemEntity? _selectedItem;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final defaultItems = widget.availableStock.isNotEmpty
        ? widget.availableStock
        : [
            const StockItemEntity(
              id: 'stk-001',
              sku: 'SKU-RSP01',
              name: 'Respira Detox Tea (Extra Box)',
              ownerName: 'Novacare Limited',
              inventoryType: InventoryType.distributedInventory,
              description: 'Herbal lung cleanse & digestive tea.',
              price: 10000.0,
              assignedCount: 20,
              deliveredCount: 2,
              returnedCount: 0,
              totalInCustody: 18,
              reservedCount: 4,
              availableCount: 14,
              category: 'Herbal Detox',
            ),
            const StockItemEntity(
              id: 'stk-002',
              sku: 'SKU-GRZ02',
              name: 'Grazer Colon Cleanse Tea',
              ownerName: 'Novacare Limited',
              inventoryType: InventoryType.distributedInventory,
              description: 'Botanical digestive and colon detox.',
              price: 15000.0,
              assignedCount: 15,
              deliveredCount: 1,
              returnedCount: 0,
              totalInCustody: 12,
              reservedCount: 2,
              availableCount: 10,
              category: 'Digestive Care',
            ),
            const StockItemEntity(
              id: 'stk-003',
              sku: 'SKU-SLM03',
              name: 'SlimFit Herbal Metabolism Pack',
              ownerName: 'Novacare Limited',
              inventoryType: InventoryType.distributedInventory,
              description: 'Natural metabolism booster tea blend.',
              price: 12500.0,
              assignedCount: 10,
              deliveredCount: 1,
              returnedCount: 0,
              totalInCustody: 8,
              reservedCount: 1,
              availableCount: 7,
              category: 'Weight Management',
            ),
          ];

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.add_shopping_cart_rounded,
                  color: Color(0xFF10B981),
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'On-Site Upsell Product',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Deduct from vehicle inventory to add to order',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Rider Commission Entitlement Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFA7F3D0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.stars_rounded, color: Color(0xFF059669), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'You earn +₦1,500 extra commission for every successful on-site upsell drop! 💰',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF065F46),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          Text(
            'SELECT FROM VEHICLE STOCK IN CUSTODY',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 10.5,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF64748B),
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 8),

          // Product List
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 240),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: defaultItems.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (ctx, i) {
                final item = defaultItems[i];
                final isSelected = _selectedItem?.id == item.id;

                return InkWell(
                  onTap: () {
                    setState(() {
                      _selectedItem = item;
                    });
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? (isDark ? const Color(0xFF1E3A8A) : const Color(0xFFEFF6FF))
                          : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC)),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF2563EB)
                            : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                        width: isSelected ? 1.8 : 1.0,
                      ),
                    ),
                    child: Row(
                      children: [
                        Radio<String>(
                          value: item.id,
                          groupValue: _selectedItem?.id,
                          activeColor: const Color(0xFF2563EB),
                          onChanged: (_) {
                            setState(() {
                              _selectedItem = item;
                            });
                          },
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.name,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFDCFCE7),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '${item.availableCount} available',
                                      style: GoogleFonts.jetBrainsMono(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF16A34A),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    item.category,
                                    style: GoogleFonts.inter(
                                      fontSize: 10.5,
                                      color: const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Text(
                          CurrencyFormatter.formatNaira(item.price),
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF2563EB),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          // Confirm Add Upsell Action
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _selectedItem == null
                  ? null
                  : () {
                      Navigator.pop(context);
                      widget.onUpsellSelected(_selectedItem!, _selectedItem!.price);
                    },
              child: Text(
                _selectedItem != null
                    ? 'Add +1 ${_selectedItem!.name} (${CurrencyFormatter.formatNaira(_selectedItem!.price)})'
                    : 'Select a product to add',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
