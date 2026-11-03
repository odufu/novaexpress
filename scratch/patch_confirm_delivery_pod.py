import re

file_path = 'lib/features/orders/presentation/pages/confirm_delivery_pod_page.dart'
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Imports
target_import = "import '../providers/orders_provider.dart';"
replace_import = """import '../providers/orders_provider.dart';
import 'package:flutter/services.dart';
import '../../../dc_console/domain/entities/dc_finance_settings.dart';
import '../../../dc_console/presentation/providers/dc_console_provider.dart';"""
assert target_import in content, "target_import not found"
content = content.replace(target_import, replace_import, 1)

# 2. State variables
target_state_vars = """class _ConfirmDeliveryPodPageState extends ConsumerState<ConfirmDeliveryPodPage> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _referenceController = TextEditingController();"""
replace_state_vars = """class _ConfirmDeliveryPodPageState extends ConsumerState<ConfirmDeliveryPodPage> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _referenceController = TextEditingController();
  String _selectedPaymentMethod = 'cash'; // 'cash' or 'direct_transfer'
  CompanyBankAccount? _selectedCompanyAccount;"""
assert target_state_vars in content, "target_state_vars not found"
content = content.replace(target_state_vars, replace_state_vars, 1)

# 3. In initState, initialize _selectedCompanyAccount
target_postframe = """        _amountController.text = order.totalAmount.toStringAsFixed(0);
        ref.read(confirmDeliveryPodProvider.notifier).setEnteredAmount(order.totalAmount);
      }
    });"""
replace_postframe = """        _amountController.text = order.totalAmount.toStringAsFixed(0);
        ref.read(confirmDeliveryPodProvider.notifier).setEnteredAmount(order.totalAmount);
      }
      final settings = ref.read(dcConsoleProvider).financeSettings;
      if (mounted) {
        setState(() {
          _selectedCompanyAccount = settings.primaryCompanyAccount;
        });
      }
    });"""
assert target_postframe in content, "target_postframe not found"
content = content.replace(target_postframe, replace_postframe, 1)

# 4. In _submitDelivery
target_submit = """      final authState = ref.read(authProvider);
      final agentId = authState.user?.deliveryAgentId ?? authState.user?.id ?? SupabaseConstants.defaultDeliveryAgentId;
      const paymentMethod = 'cash';
      final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;
      final refNo = _referenceController.text.trim();
      final riderLoc = ref.read(riderLocationProvider);
      final ordersState = ref.read(ordersProvider);
      final orderObj = ordersState.orders.where((o) => o.id == widget.orderId || o.orderNumber == widget.orderId).firstOrNull;
      final gatePin = orderObj?.effectiveGatePin ?? 'GT-${(widget.orderId.length >= 4 ? widget.orderId.substring(widget.orderId.length - 4) : "7182").toUpperCase()}';

      final notes = refNo.isNotEmpty
          ? '[POD Collected via Cash (Ref: $refNo) • Gate PIN: $gatePin • GPS Proof: ${riderLoc.latitude.toStringAsFixed(5)}°, ${riderLoc.longitude.toStringAsFixed(5)}° (±${riderLoc.accuracyMeters.toStringAsFixed(1)}m)] Cash in custody.'
          : '[POD Collected via Cash • Gate PIN: $gatePin • GPS Proof: ${riderLoc.latitude.toStringAsFixed(5)}°, ${riderLoc.longitude.toStringAsFixed(5)}° (±${riderLoc.accuracyMeters.toStringAsFixed(1)}m)] Cash in custody.';

      await ref.read(ordersProvider.notifier).confirmDeliveryPod(
            orderId: widget.orderId,
            agentId: agentId,
            paymentType: 'pay_on_delivery',
            paymentMethod: paymentMethod,
            amountCollected: amount,
            customerSignatureUrl: podState.signatureUrl,
            photoProofUrl: podState.photoUrl,
            gatePassCode: gatePin,
            latitude: riderLoc.latitude,
            longitude: riderLoc.longitude,
            notes: notes,
          );"""

replace_submit = """      final authState = ref.read(authProvider);
      final user = authState.user;
      final agentId = user?.deliveryAgentId ?? user?.id ?? SupabaseConstants.defaultDeliveryAgentId;
      final isDirectTransfer = _selectedPaymentMethod == 'direct_transfer';
      final paymentMethod = isDirectTransfer ? 'direct_transfer' : 'cash';
      final paymentType = isDirectTransfer ? 'prepaid' : 'pay_on_delivery';
      final amount = isDirectTransfer ? 0.0 : (double.tryParse(_amountController.text.trim()) ?? 0.0);
      final refNo = _referenceController.text.trim();
      final riderLoc = ref.read(riderLocationProvider);
      final ordersState = ref.read(ordersProvider);
      final orderObj = ordersState.orders.where((o) => o.id == widget.orderId || o.orderNumber == widget.orderId).firstOrNull;
      final gatePin = orderObj?.effectiveGatePin ?? 'GT-${(widget.orderId.length >= 4 ? widget.orderId.substring(widget.orderId.length - 4) : "7182").toUpperCase()}';

      final commissionRate = (user?.commissionRate != null && user!.commissionRate > 0)
          ? user.commissionRate
          : ((user?.isInHouseRider == true || user?.isPda == false) ? 700.0 : 1000.0);
      final transportAllowance = (user?.isInHouseRider == true || user?.isPda == false)
          ? ((user?.fuelAllowance != null && user!.fuelAllowance > 0) ? user.fuelAllowance : 800.0)
          : ((user?.transportAllowance != null && user!.transportAllowance > 0) ? user.transportAllowance : 1500.0);
      final totalEntitlement = orderObj?.agentEntitlement != null && orderObj!.agentEntitlement > 0
          ? orderObj.agentEntitlement
          : (commissionRate + transportAllowance);

      final activeBank = _selectedCompanyAccount ?? ref.read(dcConsoleProvider).financeSettings.primaryCompanyAccount;

      final notes = isDirectTransfer
          ? '[DIRECT COMPANY TRANSFER to ${activeBank.bankName} (${activeBank.accountNumber}) • Ref/Sender: ${refNo.isNotEmpty ? refNo : "Paid to Company"} • Gate PIN: $gatePin • GPS Proof: ${riderLoc.latitude.toStringAsFixed(5)}°, ${riderLoc.longitude.toStringAsFixed(5)}° (±${riderLoc.accuracyMeters.toStringAsFixed(1)}m)] Credited +${CurrencyFormatter.formatNaira(totalEntitlement)} to My Balance. 0 cash held.'
          : (refNo.isNotEmpty
              ? '[POD Collected via Cash (Ref: $refNo) • Gate PIN: $gatePin • GPS Proof: ${riderLoc.latitude.toStringAsFixed(5)}°, ${riderLoc.longitude.toStringAsFixed(5)}° (±${riderLoc.accuracyMeters.toStringAsFixed(1)}m)] Cash in custody.'
              : '[POD Collected via Cash • Gate PIN: $gatePin • GPS Proof: ${riderLoc.latitude.toStringAsFixed(5)}°, ${riderLoc.longitude.toStringAsFixed(5)}° (±${riderLoc.accuracyMeters.toStringAsFixed(1)}m)] Cash in custody.');

      await ref.read(ordersProvider.notifier).confirmDeliveryPod(
            orderId: widget.orderId,
            agentId: agentId,
            paymentType: paymentType,
            paymentMethod: paymentMethod,
            amountCollected: amount,
            customerSignatureUrl: podState.signatureUrl,
            photoProofUrl: podState.photoUrl,
            gatePassCode: gatePin,
            latitude: riderLoc.latitude,
            longitude: riderLoc.longitude,
            notes: notes,
          );"""
assert target_submit in content, "target_submit not found"
content = content.replace(target_submit, replace_submit, 1)

# In notifications
target_notif = """      ref.read(notificationsProvider.notifier).emitNotification(
            title: 'Delivery POD Confirmed 🎉',
            message: 'Order $displayOrderNo was successfully delivered. Net collection of ${CurrencyFormatter.formatNaira(amount)} recorded in cash custody.',
            category: 'delivery',
            actionRoute: '/orders',
          );"""
replace_notif = """      ref.read(notificationsProvider.notifier).emitNotification(
            title: 'Delivery POD Confirmed 🎉',
            message: isDirectTransfer
                ? 'Order $displayOrderNo delivered! Payment confirmed via Direct Company Transfer. +${CurrencyFormatter.formatNaira(totalEntitlement)} credited to your withdrawable balance.'
                : 'Order $displayOrderNo was successfully delivered. Net collection of ${CurrencyFormatter.formatNaira(amount)} recorded in cash custody.',
            category: 'delivery',
            actionRoute: '/orders',
          );"""
assert target_notif in content, "target_notif not found"
content = content.replace(target_notif, replace_notif, 1)

# 5. In build method, replace lines from "// Payment Method: Enforced Cash POD" up to digital signature
target_pod_ui = """            // Payment Method: Enforced Cash POD
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF00522A).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF00522A).withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00522A),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.payments_rounded, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Payment Method: Cash POD',
                          style: GoogleFonts.inter(
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF00522A),
                          ),
                        ),
                        Text(
                          'Collect cash from customer before handing over package.',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00522A),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'CASH POD',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
              Text(
                'Enter Physical Cash Collected',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                onChanged: (v) => ref.read(confirmDeliveryPodProvider.notifier).setEnteredAmount(double.tryParse(v) ?? 0.0),
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
                decoration: InputDecoration(
                  prefixText: '₦ ',
                  prefixStyle: GoogleFonts.jetBrainsMono(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.orange,
                  ),
                  fillColor: theme.cardColor,
                  filled: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 12),

              // Cash Remittance & Settlement Breakdown Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
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
                            'CASH REMITTANCE BREAKDOWN',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                              color: const Color(0xFFF37021),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '₦100 / ₦5k Transfer Fee',
                          style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              const Icon(Icons.shopping_bag_outlined, size: 14, color: Color(0xFF64748B)),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text('Gross Cash Collected', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)), overflow: TextOverflow.ellipsis),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(CurrencyFormatter.formatNaira(enteredCash), style: GoogleFonts.jetBrainsMono(fontSize: 12.5, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              const Icon(Icons.percent_rounded, size: 14, color: Color(0xFF16A34A)),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text('Less: Commission Retained', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)), overflow: TextOverflow.ellipsis),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('-${CurrencyFormatter.formatNaira(commissionRate)}', style: GoogleFonts.jetBrainsMono(fontSize: 12.5, fontWeight: FontWeight.bold, color: const Color(0xFF16A34A))),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              const Icon(Icons.local_shipping_outlined, size: 14, color: Color(0xFF00A2D3)),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text('Less: Fuel/Transport Retained', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)), overflow: TextOverflow.ellipsis),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('-${CurrencyFormatter.formatNaira(transportAllowance)}', style: GoogleFonts.jetBrainsMono(fontSize: 12.5, fontWeight: FontWeight.bold, color: const Color(0xFF00A2D3))),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              const Icon(Icons.receipt_outlined, size: 14, color: Color(0xFFF59E0B)),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text('Less: Transfer Fee (Dynamic)', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)), overflow: TextOverflow.ellipsis),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('-${CurrencyFormatter.formatNaira(cashTransferFee)}', style: GoogleFonts.jetBrainsMono(fontSize: 12.5, fontWeight: FontWeight.bold, color: const Color(0xFFF59E0B))),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Divider(height: 1),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF37021).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'NET CASH TO REMIT TO DC',
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFFC2410C),
                                  ),
                                ),
                                Text(
                                  'You retain ${CurrencyFormatter.formatNaira(totalRetainedByRider)} in earnings & fees',
                                  style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF9A3412)),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            CurrencyFormatter.formatNaira(netCashRemittance),
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFFC2410C),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),"""

replace_pod_ui = """            // Payment Method Selector: Cash POD vs Direct Company Transfer
            Text(
              'Select Customer Payment Method',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _selectedPaymentMethod = 'cash';
                      });
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        color: _selectedPaymentMethod == 'cash'
                            ? const Color(0xFF00522A).withValues(alpha: 0.12)
                            : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _selectedPaymentMethod == 'cash'
                              ? const Color(0xFF00522A)
                              : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                          width: _selectedPaymentMethod == 'cash' ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.payments_rounded,
                            size: 20,
                            color: _selectedPaymentMethod == 'cash' ? const Color(0xFF00522A) : const Color(0xFF64748B),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Cash (POD)',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: _selectedPaymentMethod == 'cash' ? const Color(0xFF00522A) : theme.colorScheme.onSurface,
                                  ),
                                ),
                                Text(
                                  'Cash in hand',
                                  style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ),
                          if (_selectedPaymentMethod == 'cash')
                            const Icon(Icons.check_circle_rounded, size: 18, color: Color(0xFF00522A)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _selectedPaymentMethod = 'direct_transfer';
                      });
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        color: _selectedPaymentMethod == 'direct_transfer'
                            ? const Color(0xFF0284C7).withValues(alpha: 0.12)
                            : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _selectedPaymentMethod == 'direct_transfer'
                              ? const Color(0xFF0284C7)
                              : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                          width: _selectedPaymentMethod == 'direct_transfer' ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.account_balance_rounded,
                            size: 20,
                            color: _selectedPaymentMethod == 'direct_transfer' ? const Color(0xFF0284C7) : const Color(0xFF64748B),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Paid to Company',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: _selectedPaymentMethod == 'direct_transfer' ? const Color(0xFF0284C7) : theme.colorScheme.onSurface,
                                  ),
                                ),
                                Text(
                                  'Direct Bank Transfer',
                                  style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ),
                          if (_selectedPaymentMethod == 'direct_transfer')
                            const Icon(Icons.check_circle_rounded, size: 18, color: Color(0xFF0284C7)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (_selectedPaymentMethod == 'cash') ...[
              Text(
                'Enter Physical Cash Collected',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                onChanged: (v) => ref.read(confirmDeliveryPodProvider.notifier).setEnteredAmount(double.tryParse(v) ?? 0.0),
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
                decoration: InputDecoration(
                  prefixText: '₦ ',
                  prefixStyle: GoogleFonts.jetBrainsMono(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.orange,
                  ),
                  fillColor: theme.cardColor,
                  filled: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 12),

              // Cash Remittance & Settlement Breakdown Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
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
                            'CASH REMITTANCE BREAKDOWN',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                              color: const Color(0xFFF37021),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '₦100 / ₦5k Transfer Fee',
                          style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              const Icon(Icons.shopping_bag_outlined, size: 14, color: Color(0xFF64748B)),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text('Gross Cash Collected', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)), overflow: TextOverflow.ellipsis),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(CurrencyFormatter.formatNaira(enteredCash), style: GoogleFonts.jetBrainsMono(fontSize: 12.5, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              const Icon(Icons.percent_rounded, size: 14, color: Color(0xFF16A34A)),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text('Less: Commission Retained', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)), overflow: TextOverflow.ellipsis),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('-${CurrencyFormatter.formatNaira(commissionRate)}', style: GoogleFonts.jetBrainsMono(fontSize: 12.5, fontWeight: FontWeight.bold, color: const Color(0xFF16A34A))),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              const Icon(Icons.local_shipping_outlined, size: 14, color: Color(0xFF00A2D3)),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text('Less: Fuel/Transport Retained', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)), overflow: TextOverflow.ellipsis),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('-${CurrencyFormatter.formatNaira(transportAllowance)}', style: GoogleFonts.jetBrainsMono(fontSize: 12.5, fontWeight: FontWeight.bold, color: const Color(0xFF00A2D3))),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              const Icon(Icons.receipt_outlined, size: 14, color: Color(0xFFF59E0B)),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text('Less: Transfer Fee (Dynamic)', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)), overflow: TextOverflow.ellipsis),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('-${CurrencyFormatter.formatNaira(cashTransferFee)}', style: GoogleFonts.jetBrainsMono(fontSize: 12.5, fontWeight: FontWeight.bold, color: const Color(0xFFF59E0B))),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Divider(height: 1),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF37021).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'NET CASH TO REMIT TO DC',
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFFC2410C),
                                  ),
                                ),
                                Text(
                                  'You retain ${CurrencyFormatter.formatNaira(totalRetainedByRider)} in earnings & fees',
                                  style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF9A3412)),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            CurrencyFormatter.formatNaira(netCashRemittance),
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFFC2410C),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              // Company Bank Account Card for Direct Transfer
              Builder(
                builder: (context) {
                  final dcState = ref.watch(dcConsoleProvider);
                  final financeSettings = dcState.financeSettings;
                  final companyAccounts = financeSettings.companyBankAccounts;
                  final activeAccount = _selectedCompanyAccount ?? financeSettings.primaryCompanyAccount;
                  final totalRiderEntitlement = commissionRate + transportAllowance;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0B192C) : const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.35)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF0284C7),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(Icons.account_balance_rounded, color: Colors.white, size: 16),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Company Receiving Account',
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF0284C7),
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0284C7).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '0 CASH POD',
                                    style: GoogleFonts.jetBrainsMono(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF0284C7),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (companyAccounts.length > 1) ...[
                              DropdownButtonFormField<CompanyBankAccount>(
                                value: companyAccounts.any((a) => a.id == activeAccount.id) ? companyAccounts.firstWhere((a) => a.id == activeAccount.id) : companyAccounts.first,
                                decoration: InputDecoration(
                                  labelText: 'Select Company Bank Account',
                                  labelStyle: GoogleFonts.inter(fontSize: 12),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  filled: true,
                                  fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                                ),
                                items: companyAccounts.map((acc) {
                                  return DropdownMenuItem<CompanyBankAccount>(
                                    value: acc,
                                    child: Text(
                                      '${acc.bankName} - ${acc.accountNumber}',
                                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) setState(() => _selectedCompanyAccount = val);
                                },
                              ),
                              const SizedBox(height: 10),
                            ],
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          activeAccount.bankName,
                                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          activeAccount.accountNumber,
                                          style: GoogleFonts.jetBrainsMono(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 1.5,
                                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          activeAccount.accountName,
                                          style: GoogleFonts.inter(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w600,
                                            color: const Color(0xFF0284C7),
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      Clipboard.setData(ClipboardData(text: activeAccount.accountNumber));
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Copied ${activeAccount.bankName} account: ${activeAccount.accountNumber}'),
                                          duration: const Duration(seconds: 2),
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.copy_rounded, size: 14),
                                    label: const Text('Copy'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF0284C7),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Sender Name / Bank Reference Narration',
                              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _referenceController,
                              style: GoogleFonts.inter(fontSize: 13),
                              decoration: InputDecoration(
                                hintText: 'e.g. Customer Bank Name or Transfer Ref',
                                hintStyle: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
                                fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                                filled: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Direct Transfer Remittance & Earning Breakdown Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'DIRECT TRANSFER SETTLEMENT BREAKDOWN',
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.8,
                                    color: const Color(0xFF0284C7),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFDCFCE7),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'CLEARED ✓',
                                    style: GoogleFonts.jetBrainsMono(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF16A34A),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Gross Cash in Hand', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
                                Text('₦0.00 (Customer paid Company)', style: GoogleFonts.jetBrainsMono(fontSize: 12.5, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Cash Remittance to DC', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
                                Text('₦0.00 (No cash to remit)', style: GoogleFonts.jetBrainsMono(fontSize: 12.5, fontWeight: FontWeight.bold, color: const Color(0xFF16A34A))),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Plus: Commission Earned', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
                                Text('+${CurrencyFormatter.formatNaira(commissionRate)}', style: GoogleFonts.jetBrainsMono(fontSize: 12.5, fontWeight: FontWeight.bold, color: const Color(0xFF16A34A))),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Plus: Fuel/Transport Allowance', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
                                Text('+${CurrencyFormatter.formatNaira(transportAllowance)}', style: GoogleFonts.jetBrainsMono(fontSize: 12.5, fontWeight: FontWeight.bold, color: const Color(0xFF00A2D3))),
                              ],
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Divider(height: 1),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'TOTAL CREDITED TO "MY BALANCE"',
                                          style: GoogleFonts.jetBrainsMono(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.bold,
                                            color: const Color(0xFF0369A1),
                                          ),
                                        ),
                                        Text(
                                          'Company pays you via balance payout request',
                                          style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF0284C7)),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    '+${CurrencyFormatter.formatNaira(totalRiderEntitlement)}',
                                    style: GoogleFonts.jetBrainsMono(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w900,
                                      color: const Color(0xFF0369A1),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],"""
assert target_pod_ui in content, "target_pod_ui not found"
content = content.replace(target_pod_ui, replace_pod_ui, 1)

# 6. Button text & icon
target_btn = """                  icon: podState.isLoading
                      ? const SizedBox.shrink()
                      : const Icon(Icons.task_alt_rounded, size: 20),
                  label: podState.isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text(
                          'Confirm Cash Collection & POD',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),"""

replace_btn = """                  icon: podState.isLoading
                      ? const SizedBox.shrink()
                      : Icon(_selectedPaymentMethod == 'direct_transfer' ? Icons.verified_rounded : Icons.task_alt_rounded, size: 20),
                  label: podState.isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Text(
                          _selectedPaymentMethod == 'direct_transfer' ? 'Confirm Direct Transfer POD' : 'Confirm Cash Collection & POD',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),"""
assert target_btn in content, "target_btn not found"
content = content.replace(target_btn, replace_btn, 1)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("SUCCESS: confirm_delivery_pod_page.dart patched successfully!")

