import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/helpers/formatters.dart';
import '../../../../core/widgets/user_avatar_widget.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../orders/domain/entities/order.dart';
import '../../../orders/presentation/providers/orders_provider.dart';
import '../../../finance/domain/entities/remittance.dart';
import '../../../finance/presentation/providers/finance_provider.dart';
import '../../domain/entities/dc_fleet_driver.dart';
import '../providers/dc_console_provider.dart';
import 'dc_contact_rider_modal.dart';
import 'dc_order_detail_modal.dart';
import 'dc_rider_detail_modal.dart';

/// Representation of a unified Remittance lifecycle instance (Open Batch, Cleared Cash, or Direct Transfer)
class DCRemittanceLifecycleItem {
  final String id;
  final String referenceNumber;
  final String riderId;
  final String riderName;
  final String riderCode;
  final String? riderAvatarUrl;
  final String? riderPhone;
  final String type; // 'cash_pod', 'direct_transfer'
  final String status; // 'awaiting_remittance', 'verified', 'direct_settled', 'disputed'
  final DateTime openingDate;
  final DateTime? closingDate;
  final double grossAmount;
  final double commissionAmount;
  final double transportAllowance;
  final double failedStipends;
  final double posFee;
  final double netAmount;
  final List<OrderEntity> orders;
  final String paymentMethod;
  final String? depositReceiptUrl;
  final String? verifiedByName;
  final DateTime? verifiedAt;
  final String? notes;

  const DCRemittanceLifecycleItem({
    required this.id,
    required this.referenceNumber,
    required this.riderId,
    required this.riderName,
    required this.riderCode,
    this.riderAvatarUrl,
    this.riderPhone,
    required this.type,
    required this.status,
    required this.openingDate,
    this.closingDate,
    required this.grossAmount,
    this.commissionAmount = 0.0,
    this.transportAllowance = 0.0,
    this.failedStipends = 0.0,
    this.posFee = 0.0,
    required this.netAmount,
    required this.orders,
    this.paymentMethod = 'cash_to_dc',
    this.depositReceiptUrl,
    this.verifiedByName,
    this.verifiedAt,
    this.notes,
  });

  bool get isDirectTransfer => type == 'direct_transfer';
  bool get isAwaitingRemittance => status == 'awaiting_remittance' || status == 'pending';
  bool get isVerified => status == 'verified' || status == 'direct_settled' || verifiedAt != null;
  int get orderCount => orders.length;
  double get totalDeductions => commissionAmount + transportAllowance + failedStipends + posFee;
}

class DCRemittanceDetailModal extends ConsumerStatefulWidget {
  final DCRemittanceLifecycleItem remittance;

  const DCRemittanceDetailModal({
    super.key,
    required this.remittance,
  });

  @override
  ConsumerState<DCRemittanceDetailModal> createState() => _DCRemittanceDetailModalState();
}

class _DCRemittanceDetailModalState extends ConsumerState<DCRemittanceDetailModal> {
  bool _isProcessing = false;

  String _formatDateTime(DateTime? dt) {
    if (dt == null) return 'Active Route (Open)';
    return DateFormat('dd MMM yyyy, hh:mm a').format(dt);
  }

  Future<void> _verifyAndSettleRemittance(BuildContext context) async {
    final rem = widget.remittance;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 22),
              ),
              const SizedBox(width: 10),
              Text(
                'Verify & Clear Remittance',
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Confirm receipt and verification of physical cash for ${rem.riderName} (${rem.riderCode}):',
                style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B)),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    _buildModalRow('Gross Orders (${rem.orderCount}):', CurrencyFormatter.formatNaira(rem.grossAmount)),
                    const SizedBox(height: 6),
                    _buildModalRow('Total Deductions:', '-${CurrencyFormatter.formatNaira(rem.totalDeductions)}', color: const Color(0xFFEF4444)),
                    const Divider(height: 16),
                    _buildModalRow('Net Cash to Treasury:', CurrencyFormatter.formatNaira(rem.netAmount), isBold: true, color: const Color(0xFF10B981)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'This will mark all ${rem.orderCount} associated orders as Remitted & Cleared and reset rider cash custody.',
                style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF94A3B8)),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Confirm & Clear', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isProcessing = true);
    try {
      // 1. Submit/Verify in finance provider
      final user = ref.read(authProvider).user;
      final activeCompanyId = user?.companyId ?? user?.distributionCenterId ?? '22222222-2222-4222-8222-222222222222';
      final activeDcId = user?.distributionCenterId ?? '22222222-2222-4222-8222-222222222222';

      await ref.read(financeProvider.notifier).submitRemittance(
        agentId: rem.riderId,
        companyId: activeCompanyId,
        amount: rem.netAmount,
        paymentMethod: 'cash_to_dc',
        grossCollections: rem.grossAmount,
        commissionDeducted: rem.commissionAmount,
        transportAllowanceDeducted: rem.transportAllowance,
        failedStipendsDeducted: rem.failedStipends,
        posFee: rem.posFee,
        referenceNumber: rem.referenceNumber,
        notes: 'Cleared and verified into DC Treasury by supervisor',
        associatedOrders: rem.orders.map((o) => RemittanceOrderItem(
          orderId: o.id,
          orderNumber: o.orderNumber,
          customerName: o.customerName,
          status: o.status,
          paymentType: o.paymentType,
          cashCollected: o.totalAmount,
          date: o.createdAt,
        )).toList(),
      );

      // 2. Mark all contained orders as remitted in ordersProvider
      for (final order in rem.orders) {
        await ref.read(ordersProvider.notifier).updateOrderPaymentStatus(
          orderId: order.id,
          paymentStatus: 'collected',
          remittanceStatus: 'remitted',
        );
      }

      // 3. Reload live DC state
      await ref.read(ordersProvider.notifier).loadDcOrders(activeDcId);
      await ref.read(financeProvider.notifier).loadRemittances(activeDcId);

      if (mounted) {
        navigator.pop();
        messenger.showSnackBar(
          SnackBar(
            content: Text('✅ Remittance ${rem.referenceNumber} (${CurrencyFormatter.formatNaira(rem.netAmount)}) successfully cleared into DC Treasury!'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Error clearing remittance: $e'), backgroundColor: const Color(0xFFEF4444)),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Widget _buildModalRow(String label, String value, {bool isBold = false, Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
        Text(
          value,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 12.5,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: color ?? const Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isMobile = screenWidth < 768;
    final rem = widget.remittance;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 32,
        vertical: isMobile ? 16 : 24,
      ),
      child: Container(
        width: isMobile ? screenWidth : 860,
        height: screenHeight * 0.90,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.12),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            // 1. Header Toolbar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (rem.isDirectTransfer
                              ? const Color(0xFF00A2D3)
                              : (rem.isVerified ? const Color(0xFF10B981) : const Color(0xFFF59E0B)))
                          .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      rem.isDirectTransfer
                          ? Icons.bolt_rounded
                          : (rem.isVerified ? Icons.check_circle_rounded : Icons.payments_rounded),
                      color: rem.isDirectTransfer
                          ? const Color(0xFF00A2D3)
                          : (rem.isVerified ? const Color(0xFF10B981) : const Color(0xFFF59E0B)),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              rem.referenceNumber,
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _buildStatusPill(rem.status, rem.isDirectTransfer),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          rem.isDirectTransfer
                              ? 'Instant Direct Bank Settlement (Paystack / Monnify Gateway)'
                              : 'Rider Cash Custody Batch • ${rem.orderCount} Contained Orders',
                          style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // 2. Scrollable Body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // A. Rider & Timestamp Meta Strip (Interactive Tap -> Opens DCRiderDetailModal)
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          final dcState = ref.read(dcConsoleProvider);
                          final matchedDriver = dcState.drivers.where((d) =>
                              (rem.riderId.isNotEmpty && d.id == rem.riderId) ||
                              (rem.riderCode.isNotEmpty && d.driverCode.toLowerCase() == rem.riderCode.toLowerCase()) ||
                              (rem.riderName.isNotEmpty && d.name.toLowerCase() == rem.riderName.toLowerCase())
                          ).firstOrNull;

                          final driver = matchedDriver ?? DCFleetDriver(
                            id: rem.riderId.isNotEmpty ? rem.riderId : 'rider-01',
                            driverCode: rem.riderCode.isNotEmpty ? rem.riderCode : 'PDA-7000',
                            name: rem.riderName.isNotEmpty ? rem.riderName : 'Fleet Rider',
                            phone: rem.riderPhone ?? '08031234567',
                            avatarUrl: rem.riderAvatarUrl ?? '',
                            vehicleModel: 'Bajaj Boxer 150',
                            vehiclePlate: 'ABJ-894-XA',
                            vehicleType: 'Motorcycle',
                            status: 'active',
                            assignedZone: 'Abuja Municipal (Wuse / Maitama)',
                            totalAssignedOrders: rem.orders.length,
                            completedOrders: rem.orders.where((o) => o.status == 'delivered').length,
                            routeProgressPercent: 100.0,
                            efficiencyRating: 98.5,
                            cashInCustody: rem.grossAmount,
                            itemsInCustody: rem.orders.length,
                          );

                          DCRiderDetailModal.show(context, driver);
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            children: [
                              UserAvatarWidget(
                                avatarUrl: rem.riderAvatarUrl,
                                fullName: rem.riderName,
                                radius: 22,
                                showBorder: true,
                                borderColor: const Color(0xFFF37021),
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
                                            rem.riderName,
                                            style: GoogleFonts.inter(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF37021).withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.person_pin_rounded, size: 10, color: Color(0xFFF37021)),
                                              const SizedBox(width: 3),
                                              Text(
                                                'View Profile',
                                                style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFFF37021)),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Driver Code: ${rem.riderCode} • ${rem.riderPhone ?? 'Assigned Hub Personnel'}',
                                      style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.schedule_rounded, size: 13, color: Color(0xFF94A3B8)),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Opened: ${_formatDateTime(rem.openingDate)}',
                                        style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        rem.isVerified ? Icons.check_circle_outline_rounded : Icons.hourglass_top_rounded,
                                        size: 13,
                                        color: rem.isVerified ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Closed: ${_formatDateTime(rem.closingDate)}',
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: rem.isVerified ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(width: 6),
                              const Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFF94A3B8)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // B. 4 Contextual Metric Cards
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final cardWidth = isMobile ? (constraints.maxWidth - 8) / 2 : (constraints.maxWidth - 24) / 4;
                        return Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildKpiTile('GROSS VALUE', CurrencyFormatter.formatNaira(rem.grossAmount), '${rem.orderCount} Orders', const Color(0xFF2563EB), cardWidth, isDark),
                            _buildKpiTile('DEDUCTIONS', '-${CurrencyFormatter.formatNaira(rem.totalDeductions)}', 'Commission & Fees', const Color(0xFFEF4444), cardWidth, isDark),
                            _buildKpiTile(
                              rem.isVerified ? 'CLEARED NET' : 'NET DUE TO DC',
                              CurrencyFormatter.formatNaira(rem.netAmount),
                              rem.isVerified ? 'In DC Treasury' : 'Held in Vehicle',
                              const Color(0xFF10B981),
                              cardWidth,
                              isDark,
                            ),
                            _buildKpiTile('CHANNEL', rem.paymentMethod.replaceAll('_', ' ').toUpperCase(), rem.isDirectTransfer ? 'Instant' : 'Cash Batch', const Color(0xFF8B5CF6), cardWidth, isDark),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 18),

                    // C. Financial Breakdown Ledger Card (Cumulative)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.receipt_long_rounded, size: 16, color: Color(0xFFF37021)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Cumulative Financial Settlement Breakdown',
                                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildLedgerRow('Gross Order Collections (${rem.orderCount} orders)', CurrencyFormatter.formatNaira(rem.grossAmount), isDark),
                          const SizedBox(height: 6),
                          _buildLedgerRow(
                            'Less: Rider Delivery Commission (${rem.orderCount} @ ₦1,000)',
                            '-${CurrencyFormatter.formatNaira(rem.commissionAmount)}',
                            isDark,
                            isDeduction: true,
                          ),
                          const SizedBox(height: 6),
                          _buildLedgerRow('Less: Fuel & Route Transport Allowance', '-${CurrencyFormatter.formatNaira(rem.transportAllowance)}', isDark, isDeduction: true),
                          if (rem.failedStipends > 0) ...[
                            const SizedBox(height: 6),
                            _buildLedgerRow('Less: Failed Delivery Stipends', '-${CurrencyFormatter.formatNaira(rem.failedStipends)}', isDark, isDeduction: true),
                          ],
                          const SizedBox(height: 6),
                          _buildLedgerRow(
                            'Less: POS / Gateway Transfer Charge (DC Policy Tier)',
                            '-${CurrencyFormatter.formatNaira(rem.posFee)}',
                            isDark,
                            isDeduction: true,
                          ),
                          const Divider(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  rem.isVerified ? 'Total Net Cleared to Treasury:' : 'Net Remittance Payable to DC:',
                                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                CurrencyFormatter.formatNaira(rem.netAmount),
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFF10B981),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // D. Orders Contained in Remittance Batch
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              const Icon(Icons.inventory_2_rounded, size: 16, color: Color(0xFF2563EB)),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  'Orders Contained in Batch (${rem.orderCount})',
                                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Tap order for Proof of Delivery (POD)',
                          style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Orders List
                    if (rem.orders.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                        ),
                        child: Center(
                          child: Text('No individual order records attached to this batch reference.', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: rem.orders.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (ctx, idx) {
                          final order = rem.orders[idx];
                          return _buildOrderRowItem(order, isDark);
                        },
                      ),
                  ],
                ),
              ),
            ),

            // 3. Bottom Action Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                border: Border(top: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      final fallbackOrder = rem.orders.isNotEmpty
                          ? rem.orders.first
                          : OrderEntity(
                              id: rem.id,
                              orderNumber: rem.referenceNumber,
                              customerName: rem.riderName,
                              customerPhone: rem.riderPhone ?? '08000000000',
                              deliveryState: 'FCT - Abuja',
                              deliveryCity: 'Abuja',
                              deliveryAddress: 'DC Hub Delivery',
                              status: 'delivered',
                              quantity: rem.orderCount,
                              basePrice: rem.grossAmount,
                              upsellAmount: 0.0,
                              totalAmount: rem.grossAmount,
                              paymentType: rem.paymentMethod,
                              paymentStatus: 'collected',
                              createdAt: rem.openingDate,
                            );
                      showDialog(
                        context: context,
                        builder: (ctx) => DCContactRiderModal(
                          order: fallbackOrder,
                          riderName: rem.riderName,
                          riderCode: rem.riderCode,
                          riderPhone: rem.riderPhone ?? '08000000000',
                          riderId: rem.riderId,
                          riderAvatarUrl: rem.riderAvatarUrl,
                          amountAwaitingRemittance: rem.netAmount,
                        ),
                      );
                    },
                    icon: const Icon(Icons.phone_in_talk_rounded, size: 16),
                    label: const Text('Contact Rider', style: TextStyle(fontSize: 12.5)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  Row(
                    children: [
                      if (rem.isAwaitingRemittance)
                        ElevatedButton.icon(
                          onPressed: _isProcessing ? null : () => _verifyAndSettleRemittance(context),
                          icon: _isProcessing
                              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.verified_rounded, size: 16, color: Colors.white),
                          label: Text(
                            _isProcessing ? 'Clearing...' : 'Verify & Clear (${CurrencyFormatter.formatNaira(rem.netAmount)})',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 16),
                              const SizedBox(width: 6),
                              Text(
                                'Cleared into DC Treasury',
                                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF10B981)),
                              ),
                            ],
                          ),
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
  }

  Widget _buildStatusPill(String status, bool isDirect) {
    if (isDirect) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFF00A2D3).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFF00A2D3).withValues(alpha: 0.4)),
        ),
        child: Text('⚡ DIRECT SETTLED', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF00A2D3))),
      );
    }
    if (status == 'verified' || status == 'cleared') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFF10B981).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
        ),
        child: Text('🟢 CLEARED & REMITTED', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF10B981))),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
      ),
      child: Text('🟡 AWAITING REMITTANCE', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFFF59E0B))),
    );
  }

  Widget _buildKpiTile(String title, String value, String subtitle, Color color, double width, bool isDark) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFF64748B))),
          const SizedBox(height: 4),
          Text(value, style: GoogleFonts.jetBrainsMono(fontSize: 14, fontWeight: FontWeight.bold, color: color), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(subtitle, style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF94A3B8)), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildLedgerRow(String label, String value, bool isDark, {bool isDeduction = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
        Text(
          value,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: isDeduction ? const Color(0xFFEF4444) : (isDark ? Colors.white : const Color(0xFF0F172A)),
          ),
        ),
      ],
    );
  }

  Widget _buildOrderRowItem(OrderEntity order, bool isDark) {
    return InkWell(
      onTap: () {
        showDialog(
          context: context,
          builder: (ctx) => DCOrderDetailModal(order: order),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF37021).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.local_shipping_outlined, color: Color(0xFFF37021), size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        order.orderNumber,
                        style: GoogleFonts.jetBrainsMono(fontSize: 12.5, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '• ${order.customerName}',
                        style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${order.productName} • ${order.deliveryAddress}',
                    style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  CurrencyFormatter.formatNaira(order.totalAmount),
                  style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF10B981)),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    if (order.hasSignature) ...[
                      const Icon(Icons.draw_rounded, size: 12, color: Color(0xFF10B981)),
                      const SizedBox(width: 2),
                    ],
                    if (order.hasPhotoProof) ...[
                      const Icon(Icons.camera_alt_rounded, size: 12, color: Color(0xFF2563EB)),
                      const SizedBox(width: 2),
                    ],
                    Text(
                      order.paymentType.replaceAll('_', ' ').toUpperCase(),
                      style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
