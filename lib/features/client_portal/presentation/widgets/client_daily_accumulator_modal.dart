import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/helpers/formatters.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../orders/domain/entities/order.dart';
import '../providers/client_portal_provider.dart';
import 'client_order_tracking_modal.dart';

/// Interactive modal displaying today's completed orders, live accumulated cash holdings,
/// itemized operational charges with explicit educational explanations ("what it is meant for"),
/// and expected net bank settlement at the 10:00 PM daily closeout.
class ClientDailyAccumulatorModal extends ConsumerStatefulWidget {
  const ClientDailyAccumulatorModal({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const ClientDailyAccumulatorModal(),
    );
  }

  @override
  ConsumerState<ClientDailyAccumulatorModal> createState() => _ClientDailyAccumulatorModalState();
}

class _ClientDailyAccumulatorModalState extends ConsumerState<ClientDailyAccumulatorModal> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isChargesExpanded = true;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      if (_searchQuery != _searchController.text) {
        setState(() {
          _searchQuery = _searchController.text;
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatMoney(double amount) {
    return CurrencyFormatter.formatNaira(amount)
        .replaceAll('NGN', '')
        .replaceAll('₦', '')
        .trim();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(clientPortalProvider);
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == ThemeMode.dark ||
        (themeMode == ThemeMode.system &&
            MediaQuery.of(context).platformBrightness == Brightness.dark);

    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;
    final screenWidth = mediaQuery.size.width;
    final isMobile = screenWidth < 600;

    // Filter orders matching search
    final orders = state.completedOrdersAwaitingRemittance.where((o) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase().trim();
      return o.orderNumber.toLowerCase().contains(q) ||
          o.customerName.toLowerCase().contains(q) ||
          o.customerPhone.contains(q) ||
          o.productName.toLowerCase().contains(q) ||
          o.deliveryCity.toLowerCase().contains(q);
    }).toList();

    // 10:00 PM Closeout Time Calculation
    final now = DateTime.now();
    final closeoutTime = DateTime(now.year, now.month, now.day, 22, 0); // 10:00 PM
    final isPastCloseout = now.isAfter(closeoutTime);
    final difference = isPastCloseout
        ? closeoutTime.add(const Duration(days: 1)).difference(now)
        : closeoutTime.difference(now);
    final hours = difference.inHours;
    final minutes = difference.inMinutes % 60;

    return Container(
      height: screenHeight * (isMobile ? 0.92 : 0.88),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Drag Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),

          // Header Bar
          _buildHeader(context, isDark, hours, minutes, state.todayCompletedOrdersCount),

          const Divider(height: 1),

          // Scrollable Content
          Expanded(
            child: ListView(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 14 : 24,
                vertical: 16,
              ),
              children: [
                // Hero Metrics: Gross, Charges, Net Expected Payout
                _buildHeroMetricsSection(state, isDark, isMobile),
                const SizedBox(height: 16),

                // Destination Bank Settlement Details
                _buildBankSettlementCard(state, isDark, isMobile),
                const SizedBox(height: 16),

                // Educational Charges Explainer Matrix ("What it is meant for")
                _buildChargesExplainerSection(state, isDark),
                const SizedBox(height: 20),

                // Completed Orders Header & Search
                _buildOrdersListHeader(orders.length, state.todayCompletedOrdersCount, isDark),
                const SizedBox(height: 12),

                // Orders List
                if (orders.isEmpty)
                  _buildEmptyOrdersState(isDark)
                else
                  ...orders.map((order) => _buildOrderItemCard(order, isDark, isMobile)),

                const SizedBox(height: 30),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    bool isDark,
    int hours,
    int minutes,
    int ordersCount,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 16, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0D9488), Color(0xFF047857)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.nightlight_round, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        'Live Cash Accumulator',
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
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D9488).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFF0D9488).withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Color(0xFF10B981),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'Client Settlement',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF0D9488),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  'Next automated bank settlement batch runs in ${hours}h ${minutes}m',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(
              Icons.close_rounded,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
            splashRadius: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildHeroMetricsSection(ClientPortalState state, bool isDark, bool isMobile) {
    return Column(
      children: [
        // Net Expected Payout Hero Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF042F2E), Color(0xFF134E4A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF14B8A6).withValues(alpha: 0.4)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0D9488).withValues(alpha: 0.15),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF2DD4BF), size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'EXPECTED NET CLIENT SETTLEMENT',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF2DD4BF),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Ready For Payout',
                      style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF34D399)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              FittedBox(
                alignment: Alignment.centerLeft,
                fit: BoxFit.scaleDown,
                child: Text(
                  '₦${_formatMoney(state.todayNetExpectedPayout)}',
                  style: GoogleFonts.inter(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Calculated as Gross Collections (₦${_formatMoney(state.todayGrossCashHolding)}) minus itemized operational deductions (-₦${_formatMoney(state.todayTotalChargesDeducted)}).',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: const Color(0xFF99F6E4),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Dual Sub-Cards: Gross Holding vs Total Charges
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 550;
            if (isWide) {
              return Row(
                children: [
                  Expanded(child: _buildGrossHoldingCard(state, isDark)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildChargesSummaryCard(state, isDark)),
                ],
              );
            } else {
              return Column(
                children: [
                  _buildGrossHoldingCard(state, isDark),
                  const SizedBox(height: 12),
                  _buildChargesSummaryCard(state, isDark),
                ],
              );
            }
          },
        ),
      ],
    );
  }

  Widget _buildGrossHoldingCard(ClientPortalState state, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
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
              Text(
                'Gross Cash Holding',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.savings_rounded, color: Color(0xFF2563EB), size: 16),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '₦${_formatMoney(state.todayGrossCashHolding)}',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${state.todayCompletedOrdersCount} Orders Delivered',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                  ),
                ),
              ),
              const Spacer(),
              Text(
                'In Custody',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF2563EB),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChargesSummaryCard(ClientPortalState state, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
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
              Text(
                'Operational Deductions',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFDC2626).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.receipt_long_rounded, color: Color(0xFFDC2626), size: 16),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '-₦${_formatMoney(state.todayTotalChargesDeducted)}',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: const Color(0xFFDC2626),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Logistics & Switch Fees',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                  ),
                ),
              ),
              const Spacer(),
              Text(
                'Itemized Below',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFDC2626),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBankSettlementCard(ClientPortalState state, bool isDark, bool isMobile) {
    final profile = state.clientProfile;
    final bankName = profile.bankName.isNotEmpty ? profile.bankName : 'Access Bank';
    final accNumber = profile.accountNumber.isNotEmpty ? profile.accountNumber : '0123456789';
    final accName = profile.accountName.isNotEmpty ? profile.accountName : profile.companyName;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0D9488).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.account_balance_rounded, color: Color(0xFF0D9488), size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Destination Settlement Account',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0D9488),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.verified_rounded, color: Color(0xFF0D9488), size: 14),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '$bankName • $accNumber',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Beneficiary: $accName (Instant NIBSS / Paystack Clearing at 22:00)',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChargesExplainerSection(ClientPortalState state, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Collapsible Header
          InkWell(
            onTap: () {
              setState(() {
                _isChargesExpanded = !_isChargesExpanded;
              });
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF37021).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.info_outline_rounded, color: Color(0xFFF37021), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Operational Deductions Explainer',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          'Itemized breakdown of charges deducted from gross cash holdings and what each is meant for',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _isChargesExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ],
              ),
            ),
          ),

          if (_isChargesExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // 1. Last-Mile Logistics Delivery Fee
                  _buildChargeTile(
                    icon: Icons.local_shipping_rounded,
                    iconColor: const Color(0xFF2563EB),
                    title: '1. Last-Mile Logistics Delivery Fee',
                    amount: '-₦${_formatMoney(state.todayLogisticsDeliveryFees)}',
                    purpose: 'Doorstep Rider Transit & Handover Compensation',
                    explanation:
                        'Directly compensates the dispatch rider for fuel, vehicle transit, doorstep customer verification, and successful package handover across ${state.todayCompletedOrdersCount} delivered orders today (Negotiated: ₦${_formatMoney(state.clientProfile.customDeliveryFee ?? 5000)}/order).',
                    isDark: isDark,
                  ),

                  const SizedBox(height: 12),

                  // 2. Failed Delivery Surcharge
                  _buildChargeTile(
                    icon: Icons.replay_rounded,
                    iconColor: const Color(0xFFDC2626),
                    title: '2. Failed Delivery Surcharge',
                    amount: state.todayFailedAttemptFees > 0
                        ? '-₦${_formatMoney(state.todayFailedAttemptFees)}'
                        : '₦0.00 (Zero Failed Drops Today)',
                    purpose: 'Reverse Transit & Warehouse Re-shelving Coverage',
                    explanation:
                        'Compensates the dispatch rider and covers reverse logistics handling when an order delivery fails (customer unavailable, cancelled, or rejected). Charged at negotiated ₦${_formatMoney(state.clientProfile.customFailedAttemptFee ?? 1000)} per failed drop.',
                    isDark: isDark,
                  ),

                  const SizedBox(height: 12),

                  // 3. Platform Charge (Third-Party Switch + System Operations)
                  _buildChargeTile(
                    icon: Icons.hub_rounded,
                    iconColor: const Color(0xFF8B5CF6),
                    title: '3. Platform Charge (Switch + App Operational Finance)',
                    amount: '-₦${_formatMoney(state.todayPlatformClearingFees)}',
                    purpose: 'App Infrastructure, Technical Team, Upgrades & Payment Switch',
                    explanation:
                        'Platform Charge = Third-Party Provider Switch Fee (₦${_formatMoney(state.todayThirdPartySwitchFees)} for digital & COD bank remittance) + System Operation Charge (₦${_formatMoney(state.todaySystemOperationCharges)}). The System Operation Charge is dedicated exclusively to platform infrastructure maintenance, engineering technical team, upgrades, and feature additions.',
                    isDark: isDark,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChargeTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String amount,
    required String purpose,
    required String explanation,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      purpose,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: iconColor,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                amount,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: amount.startsWith('-')
                      ? const Color(0xFFDC2626)
                      : (isDark ? const Color(0xFF10B981) : const Color(0xFF047857)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            explanation,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrdersListHeader(int filteredCount, int totalCount, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(
                  'Delivered Orders Awaiting Settlement',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$totalCount Delivered',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF2563EB),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Individual completed customer orders with itemized gross payment and delivery charge breakdown.',
          style: GoogleFonts.inter(
            fontSize: 11,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search order number, customer, product, or city...',
            hintStyle: GoogleFonts.inter(fontSize: 12),
            prefixIcon: const Icon(Icons.search_rounded, size: 18),
            filled: true,
            fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyOrdersState(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Icon(Icons.inventory_2_outlined, size: 48, color: isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8)),
          const SizedBox(height: 12),
          Text(
            'No Delivered Orders Awaiting Remittance',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'All orders completed by riders today will appear here along with cash accumulation awaiting client settlement.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderItemCard(OrderEntity order, bool isDark, bool isMobile) {
    final netAmount = order.totalAmount - order.clientDeliveryFee;
    final isDirect = order.isDirectTransfer;
    final deliveryTime = order.deliveredAt != null
        ? DateFormat('hh:mm a • MMM d').format(order.deliveredAt!)
        : 'Delivered Today';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Order Number & Net Amount Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          order.orderNumber,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'DELIVERED',
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF10B981),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${order.customerName} • ${order.customerPhone}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Net: ₦${_formatMoney(netAmount)}',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0D9488),
                    ),
                  ),
                  Text(
                    'Gross ₦${_formatMoney(order.totalAmount)}',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 10),

          // Product & Package info
          Row(
            children: [
              const Icon(Icons.inventory_2_rounded, size: 14, color: Color(0xFFF37021)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${order.productName} • ${order.packageName ?? "Standard Package"} (Qty: ${order.quantity})',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

          // Custody & Delivery Location
          Row(
            children: [
              const Icon(Icons.location_on_rounded, size: 14, color: Color(0xFF64748B)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${order.deliveryAddress}, ${order.deliveryCity}, ${order.deliveryState}',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Financial Breakdown Pills
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Payment Type Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isDirect
                      ? const Color(0xFF0D9488).withValues(alpha: 0.15)
                      : const Color(0xFF2563EB).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isDirect ? Icons.credit_card_rounded : Icons.money_rounded,
                      size: 12,
                      color: isDirect ? const Color(0xFF0D9488) : const Color(0xFF2563EB),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isDirect ? 'Direct Bank Transfer' : 'Physical Cash (In DC Vault)',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isDirect ? const Color(0xFF0D9488) : const Color(0xFF2563EB),
                      ),
                    ),
                  ],
                ),
              ),

              // Delivery Fee Deduction Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFDC2626).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Delivery Fee: -₦${_formatMoney(order.clientDeliveryFee)}',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFDC2626),
                  ),
                ),
              ),

              // Delivered Time Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  deliveryTime,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
              ),

              // Tracking Action Button
              InkWell(
                onTap: () => ClientOrderTrackingModal.show(context, order),
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Audit Trail',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFF37021),
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(Icons.arrow_forward_ios_rounded, size: 8, color: Color(0xFFF37021)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
