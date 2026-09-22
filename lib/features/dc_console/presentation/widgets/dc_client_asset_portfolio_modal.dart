import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../client_portal/domain/entities/client_profile.dart';
import '../../../client_portal/domain/entities/client_settlement.dart';
import '../../../client_portal/presentation/widgets/client_settlement_detail_modal.dart';
import '../../../orders/domain/entities/order.dart';
import '../../../orders/presentation/providers/orders_provider.dart';
import '../../presentation/providers/product_catalog_provider.dart';
import '../../presentation/providers/dc_console_provider.dart';
import '../../domain/entities/product_package.dart';
import '../../../stock/domain/entities/stock_item.dart';
import '../../../stock/presentation/providers/stock_provider.dart';
import '../../../pipeline_chat/presentation/widgets/order_pipeline_chat_sheet.dart';
import 'dc_daily_merchant_settlement_modal.dart';
import 'dc_edit_client_modal.dart';

class DCClientAssetPortfolioModal extends ConsumerStatefulWidget {
  final ClientProfile client;

  const DCClientAssetPortfolioModal({
    super.key,
    required this.client,
  });

  static Future<void> show(BuildContext context, ClientProfile client) {
    return showDialog(
      context: context,
      builder: (ctx) => DCClientAssetPortfolioModal(client: client),
    );
  }

  @override
  ConsumerState<DCClientAssetPortfolioModal> createState() =>
      _DCClientAssetPortfolioModalState();
}

class _DCClientAssetPortfolioModalState
    extends ConsumerState<DCClientAssetPortfolioModal>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late ClientProfile _client;

  late final TextEditingController _deliveryFeeController;
  late final TextEditingController _failedFeeController;
  late final TextEditingController _platformFeeController;
  late final TextEditingController _bankNameController;
  late final TextEditingController _bankAccountNumberController;
  late final TextEditingController _bankAccountNameController;
  bool _isSavingFinancials = false;

  @override
  void initState() {
    super.initState();
    _client = widget.client;
    _tabController = TabController(length: 6, vsync: this);
    _deliveryFeeController = TextEditingController(
      text: (_client.customDeliveryFee ?? 5000.0).toStringAsFixed(0),
    );
    _failedFeeController = TextEditingController(
      text: (_client.customFailedAttemptFee ?? 1000.0).toStringAsFixed(0),
    );
    _platformFeeController = TextEditingController(
      text: (_client.customPlatformFeeValue ?? 500.0).toStringAsFixed(0),
    );
    _bankNameController = TextEditingController(text: _client.bankName);
    _bankAccountNumberController = TextEditingController(text: _client.accountNumber);
    _bankAccountNameController = TextEditingController(
      text: _client.accountName.isNotEmpty ? _client.accountName : _client.companyName,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _deliveryFeeController.dispose();
    _failedFeeController.dispose();
    _platformFeeController.dispose();
    _bankNameController.dispose();
    _bankAccountNumberController.dispose();
    _bankAccountNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currency = NumberFormat.currency(locale: 'en_NG', symbol: '₦', decimalDigits: 0);

    final catalogState = ref.watch(productCatalogProvider);
    final clientProducts = catalogState.products.where((p) {
      return p.clientId == _client.id ||
          p.clientName.toLowerCase() == _client.companyName.toLowerCase();
    }).toList();

    final stockState = ref.watch(stockProvider);
    final clientStockItems = stockState.stockItems.where((s) {
      return s.clientId == _client.id ||
          s.ownerName.toLowerCase() == _client.companyName.toLowerCase();
    }).toList();

    final ordersState = ref.watch(ordersProvider);
    final clientOrders = ordersState.orders.where((o) {
      return o.clientId == _client.id ||
          o.clientName.toLowerCase() == _client.companyName.toLowerCase();
    }).toList();

    // Financial Metrics
    final totalOrderValue = clientOrders.fold(0.0, (sum, o) => sum + o.totalAmount);
    final deliveredOrders = clientOrders.where((o) => o.status.toLowerCase() == 'delivered').toList();
    final unsettledDeliveredOrders = deliveredOrders.where((o) => !o.isClientSettled).toList();
    final codCollected = deliveredOrders.fold(0.0, (sum, o) => sum + o.totalAmount);

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: double.infinity,
        constraints: BoxConstraints(
          maxWidth: 960,
          maxHeight: MediaQuery.of(context).size.height * 0.92,
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Client Info & Dismiss
            Row(
              children: [
                _buildClientAvatar(_client, size: 48, iconSize: 26),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              _client.companyName,
                              style: GoogleFonts.inter(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0D9488).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _client.code,
                              style: GoogleFonts.inter(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF0D9488),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: (_client.isActive ? const Color(0xFF10B981) : const Color(0xFFEF4444)).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _client.isActive ? 'Active' : 'Deactivated',
                              style: GoogleFonts.inter(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: _client.isActive ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_client.contactPerson} • ${_client.phone} • ${_client.city}, ${_client.state}',
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    final updated = await DCEditClientModal.show(context, _client);
                    if (updated != null && mounted) {
                      setState(() => _client = updated);
                    }
                  },
                  icon: const Icon(Icons.edit_note_rounded, size: 15, color: Color(0xFF0D9488)),
                  label: Text(
                    'Edit Profile & Brand',
                    style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700, color: const Color(0xFF0D9488)),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF0D9488)),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Top Summary Cards
            LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxWidth < 650;
                final chips = [
                  _buildKpiChip(
                    title: 'Catalog Products',
                    value: '${clientProducts.length}',
                    subtitle: '${clientProducts.fold(0, (s, p) => s + p.packages.length)} Packages',
                    icon: Icons.inventory_2_outlined,
                    color: const Color(0xFF0D9488),
                    isDark: isDark,
                  ),
                  _buildKpiChip(
                    title: 'Total Stock in Network',
                    value: '${clientStockItems.fold(0, (s, i) => s + i.totalStock)}',
                    subtitle: 'Units Across Hubs',
                    icon: Icons.warehouse_rounded,
                    color: const Color(0xFF6366F1),
                    isDark: isDark,
                  ),
                  _buildKpiChip(
                    title: 'Total Orders',
                    value: '${clientOrders.length}',
                    subtitle: '${deliveredOrders.length} Delivered',
                    icon: Icons.local_shipping_outlined,
                    color: const Color(0xFF0EA5E9),
                    isDark: isDark,
                  ),
                  _buildKpiChip(
                    title: 'COD Collected',
                    value: currency.format(codCollected),
                    subtitle: 'Total Delivered Value',
                    icon: Icons.payments_outlined,
                    color: const Color(0xFF10B981),
                    isDark: isDark,
                  ),
                ];

                if (isCompact) {
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: chips.map((c) => SizedBox(
                      width: constraints.maxWidth < 450 ? double.infinity : (constraints.maxWidth - 8) / 2,
                      child: c,
                    )).toList(),
                  );
                }

                return Row(
                  children: [
                    Expanded(child: chips[0]),
                    const SizedBox(width: 12),
                    Expanded(child: chips[1]),
                    const SizedBox(width: 12),
                    Expanded(child: chips[2]),
                    const SizedBox(width: 12),
                    Expanded(child: chips[3]),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),

            // Tabs
            TabBar(
              controller: _tabController,
              labelColor: const Color(0xFF0D9488),
              unselectedLabelColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              indicatorColor: const Color(0xFF0D9488),
              indicatorWeight: 3,
              labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
              tabs: const [
                Tab(text: 'Products & Packages'),
                Tab(text: 'Hub Inventory'),
                Tab(text: 'Orders & Real-time Chat'),
                Tab(text: 'Financials & Remittance'),
                Tab(text: 'Settlements'),
                Tab(text: 'Settings & Tariffs'),
              ],
            ),
            const Divider(height: 1),

            // Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildProductsAndPackagesTab(clientProducts, isDark, currency),
                  _buildHubInventoryTab(clientStockItems, isDark),
                  _buildOrdersTab(clientOrders, isDark, currency),
                  _buildFinancialsTab(codCollected, totalOrderValue, deliveredOrders, unsettledDeliveredOrders, isDark, currency),
                  _buildSettlementsTab(isDark, currency, deliveredOrders, unsettledDeliveredOrders),
                  _buildClientSettingsTab(isDark, currency),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiChip({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
                Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductsAndPackagesTab(
      List<CatalogProduct> products, bool isDark, NumberFormat currency) {
    if (products.isEmpty) {
      return Center(
        child: Text(
          'No products registered yet for this client.',
          style: GoogleFonts.inter(color: const Color(0xFF94A3B8)),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 16),
      itemCount: products.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, idx) {
        final prod = products[idx];
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
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
                  Row(
                    children: [
                      Text(
                        prod.name,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF64748B).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          prod.sku,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'Base: ${currency.format(prod.defaultUnitPrice)}',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0D9488),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: prod.packages.map((pkg) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.inventory_2_outlined, size: 14, color: Color(0xFF6366F1)),
                        const SizedBox(width: 6),
                        Text(
                          pkg.packageName,
                          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '(${pkg.quantity} units) • ${currency.format(pkg.packagePrice)}',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0D9488),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHubInventoryTab(List<StockItemEntity> items, bool isDark) {
    if (items.isEmpty) {
      return Center(
        child: Text(
          'No stock consigned to distribution centers yet.',
          style: GoogleFonts.inter(color: const Color(0xFF94A3B8)),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 16),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, idx) {
        final item = items[idx];
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    'SKU: ${item.sku} • Category: ${item.category}',
                    style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
                  ),
                ],
              ),
              Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${item.totalStock} Units',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0D9488),
                        ),
                      ),
                      Text(
                        'Across regional hubs',
                        style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF64748B)),
                      ),
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

  Widget _buildOrdersTab(List<OrderEntity> orders, bool isDark, NumberFormat currency) {
    if (orders.isEmpty) {
      return Center(
        child: Text(
          'No orders currently associated with this client.',
          style: GoogleFonts.inter(color: const Color(0xFF94A3B8)),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 16),
      itemCount: orders.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, idx) {
        final order = orders[idx];
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          order.orderNumber,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0D9488).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            order.status.toUpperCase(),
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0D9488),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Customer: ${order.customerName} • ${order.deliveryCity}, ${order.deliveryState}',
                      style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  currency.format(order.totalAmount),
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0D9488),
                  ),
                ),
              ),
              // Open Chat Pipeline Button
              ElevatedButton.icon(
                onPressed: () {
                  OrderPipelineChatSheet.show(
                    context,
                    orderId: order.id,
                    orderNumber: order.orderNumber,
                    customerName: order.customerName,
                    customerPhone: order.customerPhone,
                  );
                },
                icon: const Icon(Icons.chat_bubble_outline_rounded, size: 14, color: Colors.white),
                label: Text(
                  'Order Chat',
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D9488),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFinancialsTab(
      double codCollected, double totalOrderValue, List<OrderEntity> deliveredOrders, List<OrderEntity> unsettledDeliveredOrders, bool isDark, NumberFormat currency) {
    final effectiveDeliveryFee = _client.customDeliveryFee ?? 5000.0;
    final effectiveFailedFee = _client.customFailedAttemptFee ?? 1000.0;
    final effectivePlatformFee = _client.customPlatformFeeValue ?? 500.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Active Negotiated Tariffs Overview Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(14),
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
                    Row(
                      children: [
                        const Icon(Icons.handshake_rounded, color: Color(0xFF0D9488), size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Negotiated Operational Agreement',
                          style: GoogleFonts.inter(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                    TextButton.icon(
                      onPressed: () => _tabController.animateTo(4),
                      icon: const Icon(Icons.edit_note_rounded, size: 16, color: Color(0xFF0D9488)),
                      label: Text(
                        'Edit Tariffs',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF0D9488)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    _buildTariffPill(
                      label: '1. Delivery Fee',
                      value: '₦${currency.format(effectiveDeliveryFee).replaceAll('₦', '')}',
                      subtitle: 'Per delivered order',
                      color: const Color(0xFF2563EB),
                      isDark: isDark,
                    ),
                    _buildTariffPill(
                      label: '2. Failed Attempt',
                      value: '₦${currency.format(effectiveFailedFee).replaceAll('₦', '')}',
                      subtitle: 'Per failed attempt',
                      color: const Color(0xFFDC2626),
                      isDark: isDark,
                    ),
                    _buildTariffPill(
                      label: '3. Platform Fee',
                      value: '₦${currency.format(effectivePlatformFee).replaceAll('₦', '')}',
                      subtitle: 'App Operational Finance',
                      color: const Color(0xFF8B5CF6),
                      isDark: isDark,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 2. Settlement & Banking Profile
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.account_balance_rounded, color: Color(0xFF0D9488), size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Settlement & Banking Profile',
                      style: GoogleFonts.inter(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Bank Name', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8))),
                          Text(
                            _client.bankName.isNotEmpty ? _client.bankName : 'Not Set',
                            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Account Number', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8))),
                          Text(
                            _client.accountNumber.isNotEmpty ? _client.accountNumber : 'Not Set',
                            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Account Name', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8))),
                          Text(
                            _client.accountName.isNotEmpty ? _client.accountName : _client.companyName,
                            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // 3. Remittance Batch Trigger
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Remittance Actions',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    '${unsettledDeliveredOrders.length} delivered orders awaiting client settlement',
                    style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () {
                  DCDailyMerchantSettlementModal.show(
                    context: context,
                    client: _client,
                    eligibleOrders: unsettledDeliveredOrders,
                  );
                },
                icon: const Icon(Icons.verified_rounded, size: 16, color: Colors.white),
                label: Text(
                  'Initiate Client Settlement',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTariffPill({
    required String label,
    required String value,
    required String subtitle,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
          const SizedBox(height: 2),
          Text(value, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF0F172A))),
          Text(subtitle, style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF64748B))),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 5: CLIENT SETTINGS & NEGOTIATED TARIFFS
  // ==========================================
  Widget _buildClientSettingsTab(bool isDark, NumberFormat currency) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF0D9488).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF0D9488).withValues(alpha: 0.25)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.verified_user_rounded, color: Color(0xFF0D9488), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Negotiated Operational Charges & Client Agreement',
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0D9488),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Update the negotiated financial tariffs for ${_client.companyName}. These rules dictate automatic daily client settlement deductions across delivery commissions, failed drop handling, and platform maintenance.',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Account Status & Security Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: (_client.isActive ? const Color(0xFF10B981) : const Color(0xFFEF4444)).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: (_client.isActive ? const Color(0xFF10B981) : const Color(0xFFEF4444)).withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _client.isActive ? Icons.verified_user_rounded : Icons.block_rounded,
                  color: _client.isActive ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                  size: 26,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Account Status: ${_client.isActive ? "ACTIVE" : "DEACTIVATED"}',
                        style: GoogleFonts.inter(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: _client.isActive ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _client.isActive
                            ? 'Client portal access and automated dispatch active for ${_client.companyName}.'
                            : 'Merchant portal logins and dispatch suspended.',
                        style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () async {
                        final email = _client.email.trim();
                        if (email.isEmpty) return;
                        try {
                          await ref.read(dcConsoleProvider.notifier).sendClientPasswordResetEmail(email);
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: const Color(0xFF10B981),
                              content: Text('Password reset email dispatched to $email!'),
                            ),
                          );
                        } catch (e) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(backgroundColor: const Color(0xFFEF4444), content: Text('Failed: $e')),
                          );
                        }
                      },
                      icon: const Icon(Icons.email_outlined, size: 14),
                      label: const Text('Reset Password'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        final target = !_client.isActive;
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                            title: Text(target ? 'Reactivate Account?' : 'Deactivate Account?'),
                            content: Text(
                              target
                                  ? 'Restore active access for ${_client.companyName}?'
                                  : 'Suspend merchant access for ${_client.companyName}?',
                            ),
                            actions: [
                              TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: target ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: () => Navigator.of(ctx).pop(true),
                                child: Text(target ? 'Reactivate' : 'Deactivate'),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          try {
                            await ref.read(dcConsoleProvider.notifier).toggleClientActiveStatus(_client.id, target);
                            if (!mounted) return;
                            setState(() => _client = _client.copyWith(isActive: target));
                          } catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(backgroundColor: const Color(0xFFEF4444), content: Text('Error: $e')),
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _client.isActive ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      child: Text(_client.isActive ? 'Deactivate' : 'Reactivate'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 1. Operational Charges Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '1. Negotiated Operational Tariffs',
                  style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 14),

                // Delivery Fee
                _buildEditableTariffField(
                  label: 'Negotiated Delivery Fee (₦ / successful order)',
                  controller: _deliveryFeeController,
                  hint: '5000',
                  helper: 'Standard fee for Novacare is ₦5,000. Deducted from client cash holdings per delivered order.',
                  isDark: isDark,
                ),
                const SizedBox(height: 14),

                // Failed Attempt Fee
                _buildEditableTariffField(
                  label: 'Failed Delivery Surcharge (₦ / failed attempt)',
                  controller: _failedFeeController,
                  hint: '1000',
                  helper: 'Reverse transit & handling compensation when customer is unavailable or order cancelled.',
                  isDark: isDark,
                ),
                const SizedBox(height: 14),

                // Platform Charge
                _buildEditableTariffField(
                  label: 'System Operation Charge (₦ / order)',
                  controller: _platformFeeController,
                  hint: '500',
                  helper: 'Dedicated App Operational Finance for platform maintenance, tech team, upgrades, and feature additions.',
                  isDark: isDark,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 2. Third-Party Provider Switch Fee Info Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.25)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.payment_rounded, color: Color(0xFF6366F1), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Third-Party Provider Switch Fee Policy',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF6366F1),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Platform Charge = Paystack/third-party switch charge + System Operation Charge. Digital card/transfer payments incur 1.5% switch fee. Cash on Delivery (COD) in DC vault is remitted to merchant bank via electronic bank transfer switch upon client settlement.',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 3. Settlement Banking Information
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '2. Merchant Settlement Bank Details',
                  style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 14),
                _buildEditableTariffField(
                  label: 'Settlement Bank Name',
                  controller: _bankNameController,
                  hint: 'Access Bank',
                  helper: 'Commercial bank where merchant receives daily client settlement payouts.',
                  isDark: isDark,
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: _buildEditableTariffField(
                        label: 'Account Number (10-digit NUBAN)',
                        controller: _bankAccountNumberController,
                        hint: '0123456789',
                        helper: 'Valid 10-digit NUBAN',
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: _buildEditableTariffField(
                        label: 'Account Name',
                        controller: _bankAccountNameController,
                        hint: _client.companyName,
                        helper: 'Verified beneficiary corporate name',
                        isDark: isDark,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Save Button
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: _isSavingFinancials ? null : _saveClientFinancialTariffs,
              icon: _isSavingFinancials
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.save_rounded, size: 16, color: Colors.white),
              label: Text(
                _isSavingFinancials ? 'Saving Changes...' : 'Save Financial Agreement',
                style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w700, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D9488),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditableTariffField({
    required String label,
    required TextEditingController controller,
    required String hint,
    required String helper,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF0F172A)),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          style: GoogleFonts.inter(fontSize: 13),
          decoration: InputDecoration(
            hintText: hint,
            helperText: helper,
            helperStyle: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF94A3B8)),
            filled: true,
            fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF0D9488), width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
      ],
    );
  }

  Future<void> _saveClientFinancialTariffs() async {
    final delFee = double.tryParse(_deliveryFeeController.text.trim()) ?? 5000.0;
    final failFee = double.tryParse(_failedFeeController.text.trim()) ?? 1000.0;
    final platFee = double.tryParse(_platformFeeController.text.trim()) ?? 500.0;

    setState(() => _isSavingFinancials = true);

    try {
      final updated = await ref.read(dcConsoleProvider.notifier).updateClientFinancialTariffs(
        clientId: _client.id,
        customDeliveryFee: delFee,
        customFailedAttemptFee: failFee,
        customPlatformFee: platFee,
        bankName: _bankNameController.text.trim(),
        bankAccountNumber: _bankAccountNumberController.text.trim(),
        bankAccountName: _bankAccountNameController.text.trim(),
      );

      if (mounted) {
        setState(() {
          _client = updated;
          _isSavingFinancials = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '✅ Negotiated Operational Agreement updated for ${updated.companyName} (Delivery: ₦$delFee, Failed: ₦$failFee, Platform: ₦$platFee).',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSavingFinancials = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error updating financial tariffs: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  // --- Settlements Tab ---
  Widget _buildSettlementsTab(
    bool isDark,
    NumberFormat currency,
    List<OrderEntity> deliveredOrders,
    List<OrderEntity> unsettledDeliveredOrders,
  ) {
    return FutureBuilder<List<ClientSettlement>>(
      future: ref.read(dcConsoleProvider.notifier).fetchDcClientSettlements(clientId: _client.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF0D9488)));
        }

        final settlements = snapshot.data ?? [];
        final totalSettledValue = settlements.fold(0.0, (sum, s) => sum + s.netPayoutAmount);
        final acknowledgedCount = settlements.where((s) => s.isCompleted).length;
        final pendingCount = settlements.where((s) => s.isRemitted || s.isPending || s.isProcessing).length;

        return ListView(
          padding: const EdgeInsets.symmetric(vertical: 12),
          children: [
            // Settlements Summary KPI Bar
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Total Net Disbursed', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8))),
                        const SizedBox(height: 3),
                        Text(
                          currency.format(totalSettledValue),
                          style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: const Color(0xFF10B981)),
                        ),
                        Text('${settlements.length} Total Batches', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8))),
                      ],
                    ),
                  ),
                  Container(width: 1, height: 40, color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Acknowledged', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8))),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 16),
                            const SizedBox(width: 5),
                            Text(
                              '$acknowledgedCount Batches',
                              style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                            ),
                          ],
                        ),
                        Text('Confirmed by Merchant', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF10B981))),
                      ],
                    ),
                  ),
                  Container(width: 1, height: 40, color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Pending Acknowledgment', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8))),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            const Icon(Icons.schedule_rounded, color: Color(0xFFF59E0B), size: 16),
                            const SizedBox(width: 5),
                            Text(
                              '$pendingCount Batches',
                              style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                            ),
                          ],
                        ),
                        Text('Awaiting merchant sign-off', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFFF59E0B))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Shortcut: Initiate Settlement if pending orders exist
            if (unsettledDeliveredOrders.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D9488).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF0D9488).withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, color: Color(0xFF0D9488), size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '${unsettledDeliveredOrders.length} delivered orders awaiting remittance batch settlement.',
                        style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        DCDailyMerchantSettlementModal.show(
                          context: context,
                          client: _client,
                          eligibleOrders: deliveredOrders,
                        );
                      },
                      icon: const Icon(Icons.account_balance_wallet_rounded, size: 14),
                      label: const Text('Initiate Settlement Batch'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0D9488),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              ),

            // Section Title
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Historical Settlement Batches',
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700),
                ),
                Text(
                  'Click batch for itemized deductions & payment receipts',
                  style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
                ),
              ],
            ),
            const SizedBox(height: 10),

            if (settlements.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    Icon(Icons.receipt_long_outlined, size: 48, color: isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8)),
                    const SizedBox(height: 12),
                    Text(
                      'No Settlement Batches Found',
                      style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Settlements generated for this merchant will appear here along with live confirmation status and payment receipts.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              )
            else
              ...settlements.map((s) {
                final isAcknowledged = s.isCompleted;
                final isPendingAck = s.isRemitted || s.isPending || s.isProcessing;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isAcknowledged
                          ? const Color(0xFF10B981).withValues(alpha: 0.3)
                          : const Color(0xFFF59E0B).withValues(alpha: 0.3),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => ClientSettlementDetailModal.show(
                      context: context,
                      settlement: s,
                      isDcView: true,
                      clientName: _client.companyName,
                      clientLogo: _client.logoUrl,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Top row: Settlement Number, Date, Status Chip
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0D9488).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  s.settlementNumber,
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF0D9488),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                DateFormat('dd MMM yyyy, hh:mm a').format(s.settledAt),
                                style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF94A3B8)),
                              ),
                              const Spacer(),

                              // Status Chip: Acknowledged or Pending
                              if (isAcknowledged)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.verified_rounded, size: 14, color: Color(0xFF10B981)),
                                      const SizedBox(width: 5),
                                      Text(
                                        'Acknowledged & Approved',
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFF10B981),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else if (isPendingAck)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.schedule_rounded, size: 14, color: Color(0xFFF59E0B)),
                                      const SizedBox(width: 5),
                                      Text(
                                        'Disbursed • Pending Acknowledgment',
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFFF59E0B),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF64748B).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    s.status.toUpperCase(),
                                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF64748B)),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Financial Values Grid
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Net Remittance', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8))),
                                    const SizedBox(height: 2),
                                    Text(
                                      currency.format(s.netPayoutAmount),
                                      style: GoogleFonts.inter(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: const Color(0xFF10B981),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Gross Collected', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8))),
                                    const SizedBox(height: 2),
                                    Text(
                                      currency.format(s.grossCollections),
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Total Deductions', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8))),
                                    const SizedBox(height: 2),
                                    Text(
                                      currency.format(s.logisticsFeesDeducted + s.platformFeesDeducted + s.gatewayFeesDeducted + s.failedAttemptFeesDeducted),
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFFEF4444),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Delivered Orders', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8))),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${s.totalOrdersCount} Orders',
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Divider(height: 1),
                          const SizedBox(height: 10),

                          // Bank Account & Receipt Attached Chip
                          Row(
                            children: [
                              Icon(Icons.account_balance_rounded, size: 14, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                              const SizedBox(width: 6),
                              Text(
                                '${s.destinationBankName} • ${s.destinationAccountNumber} (${s.destinationAccountName})',
                                style: GoogleFonts.inter(fontSize: 11.5, color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
                              ),
                              const Spacer(),
                              if (s.hasReceipt)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0284C7).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.attach_file_rounded, size: 12, color: Color(0xFF0284C7)),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Receipt Attached',
                                        style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w700, color: const Color(0xFF0284C7)),
                                      ),
                                    ],
                                  ),
                                ),
                              const SizedBox(width: 10),
                              const Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFF94A3B8)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
          ],
        );
      },
    );
  }

  Widget _buildClientAvatar(ClientProfile client, {double size = 48, double iconSize = 26}) {
    final isEnterprise = client.isEnterprise;
    final fallbackIcon = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isEnterprise
            ? const Color(0xFF6366F1).withValues(alpha: 0.15)
            : const Color(0xFF0D9488).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        isEnterprise ? Icons.corporate_fare_rounded : Icons.storefront_rounded,
        color: isEnterprise ? const Color(0xFF6366F1) : const Color(0xFF0D9488),
        size: iconSize,
      ),
    );

    final logo = client.logoUrl?.trim();
    if (logo == null || logo.isEmpty) return fallbackIcon;

    if (logo.startsWith('data:image')) {
      try {
        final commaIdx = logo.indexOf(',');
        final base64Str = commaIdx != -1 ? logo.substring(commaIdx + 1) : logo;
        final bytes = base64Decode(base64Str.trim());
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isEnterprise
                  ? const Color(0xFF6366F1).withValues(alpha: 0.2)
                  : const Color(0xFF0D9488).withValues(alpha: 0.2),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: Padding(
              padding: const EdgeInsets.all(3),
              child: Image.memory(
                bytes,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => fallbackIcon,
              ),
            ),
          ),
        );
      } catch (_) {
        return fallbackIcon;
      }
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isEnterprise
              ? const Color(0xFF6366F1).withValues(alpha: 0.2)
              : const Color(0xFF0D9488).withValues(alpha: 0.2),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: Image.network(
            logo,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => fallbackIcon,
          ),
        ),
      ),
    );
  }
}
