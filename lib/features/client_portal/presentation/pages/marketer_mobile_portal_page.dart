import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../orders/domain/entities/order.dart';
import '../../domain/entities/lead_form.dart';
import '../providers/client_portal_provider.dart';
import '../widgets/client_form_builder_modal.dart';
import '../widgets/client_form_embed_modal.dart';

final marketerActiveTabProvider = StateProvider.autoDispose<int>((ref) => 0);
final marketerOrderSearchProvider = StateProvider.autoDispose<String>((ref) => '');

class MarketerMobilePortalPage extends ConsumerStatefulWidget {
  const MarketerMobilePortalPage({super.key});

  @override
  ConsumerState<MarketerMobilePortalPage> createState() => _MarketerMobilePortalPageState();
}

class _MarketerMobilePortalPageState extends ConsumerState<MarketerMobilePortalPage> {
  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        content: Text('✓ $label copied to clipboard!'),
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Sign Out', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Text('Are you sure you want to log out of the Digital Marketer Portal?', style: GoogleFonts.inter(fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) {
                context.go('/login');
              }
            },
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authUser = ref.watch(authProvider).user;
    final state = ref.watch(clientPortalProvider);
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == ThemeMode.dark ||
        (themeMode == ThemeMode.system &&
            MediaQuery.of(context).platformBrightness == Brightness.dark);
    final activeTab = ref.watch(marketerActiveTabProvider);
    final currencyFormatter = NumberFormat.currency(symbol: '₦', decimalDigits: 0);

    // Filter marketer's own forms and orders
    final marketerId = authUser?.marketerId ?? authUser?.id ?? '';

    final myForms = state.leadForms.where((f) =>
        (f.marketerId != null && f.marketerId == marketerId) ||
        (f.marketerId == null && state.leadForms.length == 1)).toList();

    // Marketer's orders: orders matching marketerId, or originating from myForms
    final myFormIds = myForms.map((f) => f.id).toSet();
    final myOrders = state.orders.where((o) =>
        (o.marketerId != null && o.marketerId == marketerId) ||
        (o.formId != null && myFormIds.contains(o.formId))).toList();

    // Calculate live performance
    int totalLeads = 0;
    int totalBooked = 0;
    int totalDelivered = 0;
    for (final f in myForms) {
      totalLeads += f.totalSubmissions;
      totalBooked += f.totalOrdersBooked;
      totalDelivered += f.totalOrdersDelivered;
    }

    final double convRate = totalLeads > 0 ? ((totalDelivered / totalLeads) * 100) : 0.0;
    final double earnedCommission = totalDelivered * 1000.0;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF090E17) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF111827) : Colors.white,
        elevation: 0,
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.campaign_rounded, color: Color(0xFF10B981), size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          authUser?.fullName ?? 'Digital Marketer',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          authUser?.marketerCode ?? 'MKT',
                          style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFF10B981)),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    state.clientProfile.companyName.isNotEmpty
                        ? state.clientProfile.companyName
                        : 'Merchant Marketing Partner',
                    style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              color: isDark ? const Color(0xFFFBBF24) : const Color(0xFF64748B),
              size: 20,
            ),
            onPressed: () => ref.read(themeProvider.notifier).toggleTheme(),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444), size: 20),
            tooltip: 'Sign Out',
            onPressed: () => _confirmLogout(context),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF111827) : Colors.white,
          border: Border(top: BorderSide(color: isDark ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0))),
        ),
        child: BottomNavigationBar(
          currentIndex: activeTab,
          onTap: (index) => ref.read(marketerActiveTabProvider.notifier).state = index,
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: const Color(0xFF10B981),
          unselectedItemColor: const Color(0xFF64748B),
          selectedLabelStyle: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700),
          unselectedLabelStyle: GoogleFonts.inter(fontSize: 11),
          items: [
            BottomNavigationBarItem(
              icon: const Icon(Icons.assignment_outlined),
              activeIcon: const Icon(Icons.assignment_rounded),
              label: 'My Forms (${myForms.length})',
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.local_shipping_outlined),
              activeIcon: const Icon(Icons.local_shipping_rounded),
              label: 'Orders (${myOrders.length})',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.account_balance_wallet_outlined),
              activeIcon: Icon(Icons.account_balance_wallet_rounded),
              label: 'Earnings & Payouts',
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(clientPortalProvider.notifier).loadClientData();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Performance KPIs Header
              _buildPerformanceGrid(totalLeads, totalBooked, totalDelivered, convRate, earnedCommission, currencyFormatter, isDark),
              const SizedBox(height: 18),

              if (activeTab == 0) ...[
                // TAB 0: Lead Forms
                _buildFormsTab(myForms, marketerId, isDark),
              ] else if (activeTab == 1) ...[
                // TAB 1: Orders Pipeline
                _buildOrdersTab(myOrders, currencyFormatter, isDark),
              ] else ...[
                // TAB 2: Earnings & Payouts
                _buildEarningsTab(earnedCommission, totalDelivered, currencyFormatter, isDark),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPerformanceGrid(
    int totalLeads,
    int totalBooked,
    int totalDelivered,
    double convRate,
    double earnedCommission,
    NumberFormat currencyFormatter,
    bool isDark,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = (constraints.maxWidth - 10) / 2;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _buildStatCard('Leads Ingested', '$totalLeads', Icons.touch_app_rounded, const Color(0xFF6366F1), cardWidth, isDark),
            _buildStatCard('Orders Booked', '$totalBooked', Icons.phone_callback_rounded, const Color(0xFFF59E0B), cardWidth, isDark),
            _buildStatCard('Orders Delivered', '$totalDelivered', Icons.verified_rounded, const Color(0xFF10B981), cardWidth, isDark),
            _buildStatCard('Conversion Rate', '${convRate.toStringAsFixed(1)}%', Icons.insights_rounded, const Color(0xFF0EA5E9), cardWidth, isDark),
          ],
        );
      },
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, double width, bool isDark) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111827) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF64748B))),
              Icon(icon, color: color, size: 16),
            ],
          ),
          const SizedBox(height: 6),
          Text(value, style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF0F172A))),
        ],
      ),
    );
  }

  Widget _buildFormsTab(List<LeadForm> myForms, String marketerId, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'My Campaign Lead Forms',
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF0F172A)),
            ),
            ElevatedButton.icon(
              onPressed: () => ClientFormBuilderModal.show(context, initialMarketerId: marketerId),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.add_rounded, size: 16, color: Colors.white),
              label: Text('New Form', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (myForms.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF111827) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0)),
            ),
            child: Center(
              child: Column(
                children: [
                  const Icon(Icons.assignment_late_outlined, size: 40, color: Color(0xFF94A3B8)),
                  const SizedBox(height: 10),
                  Text('No forms created yet', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF64748B))),
                  const SizedBox(height: 4),
                  Text('Create a lead form for your Facebook / TikTok ad campaigns', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8))),
                  const SizedBox(height: 14),
                  ElevatedButton.icon(
                    onPressed: () => ClientFormBuilderModal.show(context, initialMarketerId: marketerId),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
                    icon: const Icon(Icons.add_rounded, size: 16, color: Colors.white),
                    label: Text('Create Form', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
                ],
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: myForms.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final form = myForms[index];
              final origin = Uri.base.origin.isNotEmpty ? Uri.base.origin : 'https://portal.novaexpress.ng';
              final directUrl = '$origin/#/f/${form.id}';

              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF111827) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            form.title,
                            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${form.totalSubmissions} Leads',
                            style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFF10B981)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '📦 ${form.productName} • ${form.packages.length} Packages',
                      style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 10),

                    // Quick Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF10B981),
                              side: const BorderSide(color: Color(0xFF10B981)),
                              padding: const EdgeInsets.symmetric(vertical: 6),
                            ),
                            icon: const Icon(Icons.link_rounded, size: 14),
                            label: Text('Copy Link', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700)),
                            onPressed: () => _copyToClipboard(directUrl, 'Direct Checkout Link'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              padding: const EdgeInsets.symmetric(vertical: 6),
                            ),
                            icon: const Icon(Icons.code_rounded, size: 14, color: Colors.white),
                            label: Text('Get Embed', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
                            onPressed: () => ClientFormEmbedModal.show(context, form: form),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF6366F1)),
                          tooltip: 'Edit Form',
                          onPressed: () => ClientFormBuilderModal.show(context, existingForm: form, initialMarketerId: marketerId),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildOrdersTab(List<OrderEntity> orders, NumberFormat currencyFormatter, bool isDark) {
    if (orders.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF111827) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0)),
        ),
        child: Center(
          child: Column(
            children: [
              const Icon(Icons.shopping_bag_outlined, size: 40, color: Color(0xFF94A3B8)),
              const SizedBox(height: 10),
              Text('No orders generated yet', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF64748B))),
              const SizedBox(height: 4),
              Text('When customers fill your forms, orders appear here in real time', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8))),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Attributed Orders Pipeline (${orders.length})',
          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF0F172A)),
        ),
        const SizedBox(height: 10),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: orders.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final order = orders[index];
            final isDelivered = order.isDelivered;
            final isFailed = order.isFailed;

            Color statusColor = const Color(0xFFF59E0B);
            if (isDelivered) {
              statusColor = const Color(0xFF10B981);
            } else if (isFailed) {
              statusColor = const Color(0xFFEF4444);
            }

            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF111827) : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isDark ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: statusColor.withValues(alpha: 0.12),
                    child: Icon(
                      isDelivered ? Icons.check_circle_rounded : (isFailed ? Icons.cancel_rounded : Icons.local_shipping_rounded),
                      color: statusColor,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              order.customerName,
                              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                            ),
                            const SizedBox(width: 6),
                            Text('• #${order.orderNumber}', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8))),
                          ],
                        ),
                        Text(
                          '${order.productName} • ${order.deliveryCity}, ${order.deliveryState}',
                          style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(currencyFormatter.format(order.totalAmount), style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                      Text(order.status.replaceAll('_', ' ').toUpperCase(), style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: statusColor)),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildEarningsTab(double earnedCommission, int totalDelivered, NumberFormat currencyFormatter, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111827) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('COMMISSION & DISBURSEMENT LEDGER', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF10B981), letterSpacing: 0.5)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Earned Commission Balance', style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B))),
              Text(
                currencyFormatter.format(earnedCommission),
                style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: const Color(0xFF10B981)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Delivered Orders Qualifying', style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B))),
              Text(
                '$totalDelivered Orders',
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A)),
              ),
            ],
          ),
          const Divider(height: 24),
          Text(
            'Commissions are disbursed automatically by the merchant to your designated bank account upon delivery reconciliation.',
            style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }
}
