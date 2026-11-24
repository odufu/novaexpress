import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/helpers/formatters.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../orders/domain/entities/order.dart';
import '../../../orders/presentation/providers/orders_provider.dart';
import '../../domain/entities/dc_finance_settings.dart';
import '../../domain/entities/dc_fleet_driver.dart';
import '../providers/dc_console_provider.dart';

/// Dispatch Operations modal allowing an authorized dispatcher / DC manager
/// to tag an active order as delivered in place of a rider (or direct DC counter handover).
class MarkOrderDeliveredModal extends ConsumerStatefulWidget {
  final OrderEntity order;

  const MarkOrderDeliveredModal({
    super.key,
    required this.order,
  });

  static Future<bool?> show(BuildContext context, OrderEntity order) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => MarkOrderDeliveredModal(order: order),
    );
  }

  @override
  ConsumerState<MarkOrderDeliveredModal> createState() =>
      _MarkOrderDeliveredModalState();
}

class _MarkOrderDeliveredModalState
    extends ConsumerState<MarkOrderDeliveredModal> {
  static const String _directDcValue = '__DIRECT_DC_HANDOVER__';

  late final TextEditingController _amountController;
  late final TextEditingController _transferRefController;
  late final TextEditingController _notesController;

  late String _selectedRiderValue;
  late String _paymentMethod; // 'cash' | 'direct_transfer'
  String? _selectedBankId;
  bool _isSubmitting = false;

  static const List<String> _quickReasons = [
    'External PDA Delivery Completed (Offline Courier)',
    'Rider phone unreachable',
    'Rider app offline / dead battery',
    'DC counter customer pickup',
    'Customer confirmed delivery via call',
  ];

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.order.totalAmount.toStringAsFixed(0),
    );
    _transferRefController = TextEditingController();
    _notesController = TextEditingController();

    _paymentMethod = widget.order.isDirectTransfer ? 'direct_transfer' : 'cash';

    final assignedId = widget.order.deliveryAgentId?.trim() ?? '';
    _selectedRiderValue = assignedId.isNotEmpty ? assignedId : _directDcValue;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _transferRefController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  List<DCFleetDriver> _resolveEligibleDrivers(List<DCFleetDriver> allDrivers) {
    final dcId = widget.order.distributionCenterId?.trim() ?? '';
    final scoped = dcId.isEmpty
        ? allDrivers
        : allDrivers
            .where((d) =>
                d.distributionCenterId == null ||
                d.distributionCenterId!.isEmpty ||
                d.distributionCenterId == dcId)
            .toList();
    final source = scoped.isNotEmpty ? scoped : allDrivers;

    final seen = <String>{};
    final unique = <DCFleetDriver>[];
    for (final d in source) {
      if (d.id.isNotEmpty && seen.add(d.id)) {
        unique.add(d);
      }
    }
    if (widget.order.deliveryAgentId != null &&
        widget.order.deliveryAgentId!.isNotEmpty &&
        seen.add(widget.order.deliveryAgentId!)) {
      unique.insert(
        0,
        DCFleetDriver(
          id: widget.order.deliveryAgentId!,
          name: widget.order.deliveryAgentName ?? 'Assigned Rider',
          phone: widget.order.deliveryAgentPhone ?? '',
          driverCode: widget.order.deliveryAgentCode ?? 'PDA',
          avatarUrl: '',
          vehicleModel: 'Motorcycle',
          vehiclePlate: '',
          vehicleType: 'Motorcycle',
          status: 'active',
          assignedZone: widget.order.deliveryCity,
          totalAssignedOrders: 1,
          completedOrders: 0,
          routeProgressPercent: 100,
          efficiencyRating: 5.0,
          cashInCustody: 0,
          itemsInCustody: 0,
        ),
      );
    }
    return unique;
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final parsedAmount = double.tryParse(
          _amountController.text.replaceAll(',', '').trim(),
        ) ??
        widget.order.totalAmount;

    if (parsedAmount <= 0) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid collected amount greater than ₦0.'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final dcState = ref.read(dcConsoleProvider);
      final drivers = _resolveEligibleDrivers(dcState.drivers);
      final isDirectDc = _selectedRiderValue == _directDcValue;

      DCFleetDriver? chosenDriver;
      if (!isDirectDc) {
        chosenDriver = drivers.cast<DCFleetDriver?>().firstWhere(
              (d) =>
                  d != null &&
                  (d.id == _selectedRiderValue ||
                      d.driverCode == _selectedRiderValue),
              orElse: () => null,
            );
        if (chosenDriver == null &&
            widget.order.deliveryAgentId != null &&
            widget.order.deliveryAgentId == _selectedRiderValue) {
          chosenDriver = DCFleetDriver(
            id: widget.order.deliveryAgentId!,
            name: widget.order.deliveryAgentName ?? 'Assigned Rider',
            phone: widget.order.deliveryAgentPhone ?? '',
            driverCode: widget.order.deliveryAgentCode ?? 'PDA',
            avatarUrl: '',
            vehicleModel: 'Motorcycle',
            vehiclePlate: '',
            vehicleType: 'Motorcycle',
            status: 'active',
            assignedZone: widget.order.deliveryCity,
            totalAssignedOrders: 1,
            completedOrders: 0,
            routeProgressPercent: 100,
            efficiencyRating: 5.0,
            cashInCustody: 0,
            itemsInCustody: 0,
          );
        }
      }

      CompanyBankAccount? selectedBank;
      if (_paymentMethod == 'direct_transfer') {
        final banks = dcState.financeSettings.companyBankAccounts;
        if (banks.isNotEmpty) {
          selectedBank = banks.firstWhere(
            (b) => b.id == _selectedBankId,
            orElse: () => dcState.financeSettings.primaryCompanyAccount,
          );
        }
      }

      final result = await ref.read(ordersProvider.notifier).markOrderDeliveredByDispatch(
            orderId: widget.order.id,
            fulfillingRider: chosenDriver,
            directDcHandover: isDirectDc,
            paymentMethod: _paymentMethod,
            amountCollected: parsedAmount,
            transferReference: _transferRefController.text.trim(),
            bankName: selectedBank?.bankName,
            bankAccountNumber: selectedBank?.accountNumber,
            reasonOrNote: _notesController.text.trim(),
          );

      if (!mounted) return;
      if (result['success'] == true) {
        navigator.pop(true);
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              '✅ ${result['message'] ?? 'Order #${widget.order.orderNumber} marked delivered.'}',
            ),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      } else {
        setState(() => _isSubmitting = false);
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              result['message']?.toString() ?? 'Could not mark order delivered.',
            ),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        messenger.showSnackBar(
          SnackBar(
            content: Text('Error marking delivered: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final authUser = ref.watch(authProvider).user;
    final dcState = ref.watch(dcConsoleProvider);
    final drivers = _resolveEligibleDrivers(dcState.drivers);
    final bankAccounts = dcState.financeSettings.companyBankAccounts;
    final physicalQty = widget.order.totalPhysicalQuantity.clamp(1, 999999);

    final dropdownRiderValue = drivers.any((d) => d.id == _selectedRiderValue) ||
            _selectedRiderValue == _directDcValue
        ? _selectedRiderValue
        : _directDcValue;

    final effectiveBankId = _selectedBankId ??
        (bankAccounts.isNotEmpty
            ? dcState.financeSettings.primaryCompanyAccount.id
            : null);

    final screenSize = MediaQuery.of(context).size;
    final isMobile = screenSize.width < 600;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 14 : 28,
        vertical: 20,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 520,
          maxHeight: screenSize.height * 0.90,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.14),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  border: Border(
                    bottom: BorderSide(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.verified_rounded,
                        color: Color(0xFF10B981),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Mark Order Delivered',
                            style: GoogleFonts.inter(
                              fontSize: 15.5,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            'Dispatch Proxy POD • ${authUser?.roleDescription ?? "Dispatch Ops"}',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: const Color(0xFF64748B),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(false),
                      icon: const Icon(Icons.close_rounded, size: 20),
                    ),
                  ],
                ),
              ),

              // Body
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Order summary card
                      Container(
                        padding: const EdgeInsets.all(12),
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
                                Flexible(
                                  child: Text(
                                    '#${widget.order.orderNumber}',
                                    style: GoogleFonts.jetBrainsMono(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF2563EB),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '$physicalQty unit${physicalQty > 1 ? "s" : ""}',
                                    style: GoogleFonts.inter(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF10B981),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              widget.order.customerName,
                              style: GoogleFonts.inter(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${widget.order.productName} • ${widget.order.deliveryAddress}, ${widget.order.deliveryCity}',
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                color: const Color(0xFF64748B),
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (widget.order.deliveryAgentCode?.toUpperCase().startsWith('EXT-') == true ||
                                (widget.order.deliveryAgentName?.toLowerCase().contains('external') == true)) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFD97706).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFFD97706).withValues(alpha: 0.3)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.local_shipping_rounded, size: 14, color: Color(0xFFD97706)),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'External PDA Courier: Stock will be deducted from ${widget.order.deliveryAgentName ?? "Courier"}\'s custody.',
                                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFFD97706)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Fulfilling Rider Selection
                      Text(
                        'Fulfilling Rider / Stock Custody Source',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: dropdownRiderValue,
                        isExpanded: true,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(
                              color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                            ),
                          ),
                        ),
                        items: [
                          ...drivers.map((d) => DropdownMenuItem<String>(
                                value: d.id,
                                child: Text(
                                  '${d.name} (${d.driverCode}) • Rider Custody',
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(fontSize: 12.5),
                                ),
                              )),
                          DropdownMenuItem<String>(
                            value: _directDcValue,
                            child: Text(
                              'Direct DC Handover (No Rider — Deduct DC Shelf)',
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFFEA580C),
                              ),
                            ),
                          ),
                        ],
                        onChanged: _isSubmitting
                            ? null
                            : (val) {
                                if (val != null) {
                                  setState(() => _selectedRiderValue = val);
                                }
                              },
                      ),

                      const SizedBox(height: 14),

                      // Payment Mode Selection
                      Text(
                        'Payment Verification',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _buildPaymentOptionCard(
                              isDark: isDark,
                              selected: _paymentMethod == 'cash',
                              icon: Icons.payments_outlined,
                              title: 'Cash Collected (POD)',
                              subtitle: 'Rider holds cash to remit',
                              activeColor: const Color(0xFFF59E0B),
                              onTap: _isSubmitting
                                  ? null
                                  : () => setState(() => _paymentMethod = 'cash'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildPaymentOptionCard(
                              isDark: isDark,
                              selected: _paymentMethod == 'direct_transfer',
                              icon: Icons.account_balance_outlined,
                              title: 'Direct Transfer',
                              subtitle: 'Paid directly to company',
                              activeColor: const Color(0xFF2563EB),
                              onTap: _isSubmitting
                                  ? null
                                  : () => setState(
                                        () => _paymentMethod = 'direct_transfer',
                                      ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      // Collected Amount
                      TextFormField(
                        controller: _amountController,
                        enabled: !_isSubmitting,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                        ],
                        decoration: InputDecoration(
                          labelText: 'Amount Collected (₦)',
                          prefixText: '₦ ',
                          helperText: 'Order total: ${CurrencyFormatter.formatNaira(widget.order.totalAmount)}',
                          filled: true,
                          fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),

                      if (_paymentMethod == 'direct_transfer') ...[
                        const SizedBox(height: 12),
                        if (bankAccounts.isNotEmpty)
                          DropdownButtonFormField<String>(
                            value: bankAccounts.any((b) => b.id == effectiveBankId)
                                ? effectiveBankId
                                : bankAccounts.first.id,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: 'Receiving Company Bank Account',
                              filled: true,
                              fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            items: bankAccounts
                                .map((acc) => DropdownMenuItem<String>(
                                      value: acc.id,
                                      child: Text(
                                        '${acc.bankName} • ${acc.accountNumber}',
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.inter(fontSize: 12.5),
                                      ),
                                    ))
                                .toList(),
                            onChanged: _isSubmitting
                                ? null
                                : (val) => setState(() => _selectedBankId = val),
                          ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _transferRefController,
                          enabled: !_isSubmitting,
                          decoration: InputDecoration(
                            labelText: 'Transfer / Gateway Reference (Optional)',
                            hintText: 'e.g. MON-847291 or bank session ID',
                            filled: true,
                            fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 14),

                      // Quick Reason Chips
                      Text(
                        'Reason / Audit Remark',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: _quickReasons.map((reason) {
                          return ActionChip(
                            label: Text(reason, style: GoogleFonts.inter(fontSize: 11)),
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            onPressed: _isSubmitting
                                ? null
                                : () {
                                    _notesController.text = reason;
                                  },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _notesController,
                        enabled: !_isSubmitting,
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText: 'e.g. Rider app offline after customer confirmed delivery...',
                          filled: true,
                          fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Footer
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                  border: Border(
                    top: BorderSide(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    TextButton(
                      onPressed: _isSubmitting
                          ? null
                          : () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),
                    const Spacer(),
                    ElevatedButton.icon(
                      onPressed: _isSubmitting ? null : _submit,
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 15,
                              height: 15,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check_circle_rounded, size: 17, color: Colors.white),
                      label: Text(
                        _isSubmitting ? 'Confirming...' : 'Confirm Delivery',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentOptionCard({
    required bool isDark,
    required bool selected,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color activeColor,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: selected
              ? activeColor.withValues(alpha: 0.12)
              : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? activeColor
                : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            width: selected ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: selected ? activeColor : const Color(0xFF64748B)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: selected
                          ? activeColor
                          : (isDark ? Colors.white : const Color(0xFF0F172A)),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: GoogleFonts.inter(
                fontSize: 10,
                color: const Color(0xFF64748B),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
