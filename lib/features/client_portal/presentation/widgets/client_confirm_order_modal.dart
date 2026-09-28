import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/nigeria_locations.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../dc_console/domain/entities/distribution_center.dart';
import '../../../dc_console/presentation/providers/dc_console_provider.dart';
import '../../../orders/domain/entities/order.dart';
import '../providers/client_portal_provider.dart';

class ClientConfirmOrderModal extends ConsumerStatefulWidget {
  final OrderEntity order;

  const ClientConfirmOrderModal({super.key, required this.order});

  static Future<void> show(BuildContext context, OrderEntity order) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ClientConfirmOrderModal(order: order),
    );
  }

  @override
  ConsumerState<ClientConfirmOrderModal> createState() => _ClientConfirmOrderModalState();
}

class _ClientConfirmOrderModalState extends ConsumerState<ClientConfirmOrderModal> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _altPhoneController;
  late TextEditingController _addressController;
  late TextEditingController _notesController;
  late TextEditingController _cancellationReasonController;

  late String _selectedState;
  late String _selectedLga;
  late String _packageDealName;
  late int _quantity;
  late double _totalAmount;
  String _selectedAction = 'confirm'; // 'confirm', 'reschedule', 'cancel'
  DateTime? _scheduledCallbackDate;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.order.customerName);
    _phoneController = TextEditingController(text: widget.order.customerPhone);
    _altPhoneController = TextEditingController(text: widget.order.customerAltPhone ?? '');
    _addressController = TextEditingController(text: widget.order.deliveryAddress);
    _notesController = TextEditingController();
    _cancellationReasonController = TextEditingController();

    _packageDealName = widget.order.packageDealName ?? 'Standard Package';
    _quantity = widget.order.quantity > 0 ? widget.order.quantity : 1;
    _totalAmount = widget.order.totalAmount;

    // Initialize State & LGA with fallback to NigeriaLocations
    final stateVal = widget.order.deliveryState.trim();
    _selectedState = NigeriaLocations.states.contains(stateVal)
        ? stateVal
        : (NigeriaLocations.states.isNotEmpty ? NigeriaLocations.states.first : 'Lagos');

    final lgas = NigeriaLocations.getCitiesForState(_selectedState);
    final lgaVal = (widget.order.lga ?? widget.order.deliveryCity).trim();
    _selectedLga = lgas.contains(lgaVal)
        ? lgaVal
        : (lgas.isNotEmpty ? lgas.first : 'Ikeja');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _altPhoneController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    _cancellationReasonController.dispose();
    super.dispose();
  }

  DistributionCenter? _findCoveringDc(String lga, List<DistributionCenter> dcs) {
    if (lga.trim().isEmpty) return null;
    final cleanLga = lga.trim().toLowerCase();
    for (final dc in dcs) {
      if (!dc.isActive) continue;
      for (final z in dc.operatingZones) {
        if (z.trim().toLowerCase() == cleanLga) return dc;
      }
    }
    return null;
  }

  Future<void> _handleCloserDecision() async {
    if (_selectedAction == 'confirm' && !_formKey.currentState!.validate()) return;
    if (_selectedAction == 'cancel' && _cancellationReasonController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFFEF4444),
          content: Text('Please state the cancellation reason before rejecting the order.'),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final authUser = ref.read(authProvider).user;
      final closerId = authUser?.closerId ?? authUser?.id ?? widget.order.closerId ?? '';

      final result = await ref.read(clientPortalProvider.notifier).confirmCloserOrder(
        orderId: widget.order.id,
        closerId: closerId,
        action: _selectedAction,
        customerName: _nameController.text.trim(),
        customerPhone: _phoneController.text.trim(),
        customerAltPhone: _altPhoneController.text.trim(),
        deliveryAddress: _addressController.text.trim(),
        deliveryState: _selectedState,
        deliveryLga: _selectedLga,
        packageDealName: _packageDealName,
        quantity: _quantity,
        totalAmount: _totalAmount,
        notes: _notesController.text.trim(),
        scheduledDeliveryDate: _scheduledCallbackDate,
        cancellationReason: _cancellationReasonController.text.trim(),
      );

      if (mounted) {
        Navigator.of(context).pop();

        if (_selectedAction == 'confirm') {
          final dcName = result['distribution_center_name']?.toString() ?? 'Regional DC';
          final riderName = result['delivery_agent_name']?.toString();
          final riderCode = result['delivery_agent_code']?.toString() ?? 'PDA';
          final isMain = result['is_main_dc'] == true;

          final message = riderName != null && riderName.isNotEmpty
              ? '✅ Order #${widget.order.orderNumber} confirmed! Auto-assigned to Rider $riderName ($riderCode) at $dcName.'
              : isMain
                  ? '🚨 Order #${widget.order.orderNumber} confirmed! Out of regional coverage → Auto-routed to Main DC ($dcName).'
                  : '✅ Order #${widget.order.orderNumber} confirmed! Routed to $dcName (handling $_selectedLga).';

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: isMain ? const Color(0xFFF37021) : const Color(0xFF10B981),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              content: Row(
                children: [
                  Icon(isMain ? Icons.hub_rounded : Icons.check_circle_rounded, color: Colors.white, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      message,
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.white),
                    ),
                  ),
                ],
              ),
              duration: const Duration(seconds: 4),
            ),
          );
        } else if (_selectedAction == 'reschedule') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFF3B82F6),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              content: Text('📅 Order #${widget.order.orderNumber} scheduled for call back / follow-up.'),
            ),
          );
        } else if (_selectedAction == 'cancel') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFFEF4444),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              content: Text('❌ Order #${widget.order.orderNumber} cancelled by sales closer.'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFEF4444),
            content: Text('Failed to process closer decision: $e'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(symbol: '₦', decimalDigits: 0);
    final lgas = NigeriaLocations.getCitiesForState(_selectedState);
    final currentLgaValue = lgas.contains(_selectedLga) ? _selectedLga : (lgas.isNotEmpty ? lgas.first : null);

    final dcs = ref.watch(dcConsoleProvider).distributionCenters;
    final coveringDc = _findCoveringDc(_selectedLga, dcs);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _selectedAction == 'confirm'
                            ? const Color(0xFF10B981).withValues(alpha: 0.12)
                            : (_selectedAction == 'reschedule'
                                ? const Color(0xFF3B82F6).withValues(alpha: 0.12)
                                : const Color(0xFFEF4444).withValues(alpha: 0.12)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _selectedAction == 'confirm'
                            ? Icons.verified_rounded
                            : (_selectedAction == 'reschedule' ? Icons.phone_callback_rounded : Icons.cancel_rounded),
                        color: _selectedAction == 'confirm'
                            ? const Color(0xFF10B981)
                            : (_selectedAction == 'reschedule' ? const Color(0xFF3B82F6) : const Color(0xFFEF4444)),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Sales Closer Review & Decision',
                                style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF37021).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  widget.order.orderNumber,
                                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFFF37021)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Edit customer details after phone call & decide next stage',
                            style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF94A3B8)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Decision Action Selector Tabs
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      _buildActionTab('confirm', 'Approve & Dispatch', Icons.check_circle_rounded, const Color(0xFF10B981)),
                      _buildActionTab('reschedule', 'Call Back', Icons.schedule_rounded, const Color(0xFF3B82F6)),
                      _buildActionTab('cancel', 'Cancel Order', Icons.cancel_rounded, const Color(0xFFEF4444)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Reschedule Specific Section
                if (_selectedAction == 'reschedule') ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Select Follow-Up Callback Date & Time', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF1E40AF))),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final now = DateTime.now();
                            final date = await showDatePicker(
                              context: context,
                              initialDate: now.add(const Duration(days: 1)),
                              firstDate: now,
                              lastDate: now.add(const Duration(days: 30)),
                            );
                            if (date != null && context.mounted) {
                              final time = await showTimePicker(
                                context: context,
                                initialTime: const TimeOfDay(hour: 10, minute: 0),
                              );
                              if (time != null && mounted) {
                                setState(() {
                                  _scheduledCallbackDate = DateTime(date.year, date.month, date.day, time.hour, time.minute);
                                });
                              }
                            }
                          },
                          icon: const Icon(Icons.calendar_today_rounded, size: 16, color: Color(0xFF2563EB)),
                          label: Text(
                            _scheduledCallbackDate != null
                                ? DateFormat('EEE, d MMM yyyy - hh:mm a').format(_scheduledCallbackDate!)
                                : 'Choose Callback Date & Time',
                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF2563EB)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // Cancellation Specific Section
                if (_selectedAction == 'cancel') ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFECACA)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Reason for Cancellation *', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF991B1B))),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _cancellationReasonController,
                          maxLines: 2,
                          decoration: InputDecoration(
                            hintText: 'e.g. Customer stated they did not place this order / Price too high / Duplicate',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFFCA5A5))),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFFCA5A5))),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // Product & Amount Summary Banner
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.inventory_2_outlined, color: Color(0xFFF37021), size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${widget.order.productName} (x$_quantity)',
                              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              _packageDealName,
                              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF10B981)),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        currencyFormatter.format(_totalAmount),
                        style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: const Color(0xFF10B981)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Dynamic Distribution Center Coverage Preview
                if (_selectedAction == 'confirm') ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: coveringDc != null
                          ? const Color(0xFF10B981).withValues(alpha: 0.08)
                          : const Color(0xFFF37021).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: coveringDc != null
                            ? const Color(0xFF10B981).withValues(alpha: 0.3)
                            : const Color(0xFFF37021).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          coveringDc != null ? Icons.storefront_rounded : Icons.hub_rounded,
                          color: coveringDc != null ? const Color(0xFF10B981) : const Color(0xFFF37021),
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                coveringDc != null
                                    ? 'Covering Station: ${coveringDc.name} (${coveringDc.state})'
                                    : '🚨 No Regional DC covers "$_selectedLga"',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: coveringDc != null ? const Color(0xFF065F46) : const Color(0xFF9A3412),
                                ),
                              ),
                              Text(
                                coveringDc != null
                                    ? 'Order will be routed directly to this DC handling $_selectedLga.'
                                    : 'This order will automatically be routed to the Main DC for cross-regional handling.',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: coveringDc != null ? const Color(0xFF047857) : const Color(0xFFC2410C),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // Customer Name & Contact Phones
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Customer Name', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF334155))),
                          const SizedBox(height: 5),
                          TextFormField(
                            controller: _nameController,
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.person_outline_rounded, size: 18, color: Color(0xFF94A3B8)),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Customer Phone *', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF334155))),
                          const SizedBox(height: 5),
                          TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.phone_outlined, size: 18, color: Color(0xFF94A3B8)),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                            ),
                            validator: (v) => (v == null || v.trim().length < 10) ? 'Enter valid phone number' : null,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Alternative Phone
                Text('Alternative Phone Number (Optional)', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF334155))),
                const SizedBox(height: 5),
                TextFormField(
                  controller: _altPhoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    hintText: 'e.g. 08123456789 or Spouse/Work Phone',
                    prefixIcon: const Icon(Icons.phone_iphone_rounded, size: 18, color: Color(0xFF94A3B8)),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                  ),
                ),
                const SizedBox(height: 14),

                // State & LGA Cascade Dropdowns
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // State Selection
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Delivery State *', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF334155))),
                          const SizedBox(height: 5),
                          DropdownButtonFormField<String>(
                            value: _selectedState,
                            isExpanded: true,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                            ),
                            items: NigeriaLocations.states.map((st) {
                              return DropdownMenuItem<String>(
                                value: st,
                                child: Text(st, style: GoogleFonts.inter(fontSize: 13), overflow: TextOverflow.ellipsis),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _selectedState = val;
                                  final newLgas = NigeriaLocations.getCitiesForState(val);
                                  _selectedLga = newLgas.isNotEmpty ? newLgas.first : '';
                                });
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),

                    // LGA Selection
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Delivery LGA / Area *', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF334155))),
                          const SizedBox(height: 5),
                          DropdownButtonFormField<String>(
                            value: currentLgaValue,
                            isExpanded: true,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                            ),
                            items: lgas.map((lga) {
                              return DropdownMenuItem<String>(
                                value: lga,
                                child: Text(lga, style: GoogleFonts.inter(fontSize: 13), overflow: TextOverflow.ellipsis),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedLga = val);
                            },
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Please select LGA' : null,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Street Address & Landmark
                Text('Exact Delivery Address (House No, Street, Landmark) *', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF334155))),
                const SizedBox(height: 5),
                TextFormField(
                  controller: _addressController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'e.g. No 12, Admiralty Way, beside Zenith Bank',
                    prefixIcon: const Padding(
                      padding: EdgeInsets.only(bottom: 24),
                      child: Icon(Icons.location_on_outlined, size: 18, color: Color(0xFF94A3B8)),
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                  ),
                  validator: (v) => (_selectedAction == 'confirm' && (v == null || v.trim().length < 5)) ? 'Please enter a complete delivery address' : null,
                ),
                const SizedBox(height: 14),

                // Closer Confirmation Call Notes
                Text('Closer Call Notes (Instructions for Rider & DC)', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF334155))),
                const SizedBox(height: 5),
                TextFormField(
                  controller: _notesController,
                  decoration: InputDecoration(
                    hintText: 'e.g. Customer confirmed delivery for tomorrow morning. Cash ready.',
                    prefixIcon: const Icon(Icons.rate_review_outlined, size: 18, color: Color(0xFF94A3B8)),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                  ),
                ),
                const SizedBox(height: 20),

                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                      child: Text('Cancel', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF64748B))),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _isSubmitting ? null : _handleCloserDecision,
                      icon: _isSubmitting
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Icon(
                              _selectedAction == 'confirm'
                                  ? Icons.check_circle_outline_rounded
                                  : (_selectedAction == 'reschedule' ? Icons.schedule_rounded : Icons.delete_outline_rounded),
                              size: 17,
                              color: Colors.white,
                            ),
                      label: Text(
                        _isSubmitting
                            ? 'Processing...'
                            : (_selectedAction == 'confirm'
                                ? 'Approve & Route to DC'
                                : (_selectedAction == 'reschedule' ? 'Save Call Back' : 'Confirm Cancellation')),
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _selectedAction == 'confirm'
                            ? const Color(0xFF10B981)
                            : (_selectedAction == 'reschedule' ? const Color(0xFF3B82F6) : const Color(0xFFEF4444)),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionTab(String actionKey, String label, IconData icon, Color color) {
    final isSelected = _selectedAction == actionKey;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedAction = actionKey),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: isSelected ? color : const Color(0xFF64748B)),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? color : const Color(0xFF64748B),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
