import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../client_portal/domain/entities/client_profile.dart';
import '../../../orders/domain/entities/order.dart';
import '../../../orders/presentation/providers/orders_provider.dart';
import '../../presentation/providers/product_catalog_provider.dart';
import '../../presentation/providers/dc_console_provider.dart';
import '../../domain/entities/product_package.dart';
import '../../../stock/domain/entities/stock_item.dart';
import '../../../stock/presentation/providers/stock_provider.dart';
import '../../../pipeline_chat/presentation/widgets/order_pipeline_chat_sheet.dart';
import 'dc_daily_merchant_settlement_modal.dart';

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
    _tabController = TabController(length: 5, vsync: this);
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
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _client.isEnterprise
                        ? const Color(0xFF6366F1).withValues(alpha: 0.15)
                        : const Color(0xFF0D9488).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _client.isEnterprise
                        ? Icons.corporate_fare_rounded
                        : Icons.storefront_rounded,
                    color: _client.isEnterprise
                        ? const Color(0xFF6366F1)
                        : const Color(0xFF0D9488),
                    size: 26,
                  ),
                ),
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
}
