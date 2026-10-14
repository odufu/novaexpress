import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../core/services/location_lookup_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../client_portal/presentation/providers/client_portal_provider.dart';
import '../../../client_portal/presentation/widgets/client_create_order_modal.dart';
import '../../../dc_console/domain/entities/product_package.dart';
import '../../../dc_console/presentation/providers/dc_console_provider.dart';
import '../../../dc_console/presentation/providers/product_catalog_provider.dart';
import '../../../orders/domain/entities/order.dart';
import '../../../orders/domain/services/order_routing_service.dart';
import '../../domain/services/smart_order_parser_service.dart';

/// Modal dialog that allows telesales closers and call reps to paste raw
/// WhatsApp / CRM orders, previews parsed structured data, and converts them
/// directly into live system orders with 1 tap.
class SmartOrderPasteModal extends ConsumerStatefulWidget {
  final String? initialText;

  const SmartOrderPasteModal({
    super.key,
    this.initialText,
  });

  static Future<void> show(BuildContext context, {String? initialText}) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => SmartOrderPasteModal(initialText: initialText),
    );
  }

  @override
  ConsumerState<SmartOrderPasteModal> createState() => _SmartOrderPasteModalState();
}

class _SmartOrderPasteModalState extends ConsumerState<SmartOrderPasteModal> {
  final _textController = TextEditingController();
  final _customerNameCtrl = TextEditingController();
  final _customerPhoneCtrl = TextEditingController();
  final _customerAltPhoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _orderNumberCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();

  SmartParsedOrder? _parsedOrder;
  String _selectedState = 'Federal Capital Territory';
  String? _selectedLga = 'Abuja Municipal (AMAC)';
  List<String> _availableLgas = [];
  CatalogProduct? _selectedProduct;
  ProductPackage? _selectedPackage;
  int _quantity = 1;
  String _paymentType = 'Pay on Delivery (Cash/POS)';
  bool _isSubmitting = false;

  static const String sampleOrderText = '''Order number: Novacare Ltd-CRM-ORD-10-009197
Order date/time: 05 Oct 2026, 21:42
Customer name: +234 816 469 9784
Customer address: +234 816 469 9784
Country: Nigeria
State: Bayelsa
City: N/A
Phone number: +2348164699784
Whatsapp number: N/A
Details of products:
 - RESPIRA LUNG TEA x1 · NGN 21,500
Total order value: NGN 21,500
Amount to collect: NGN 21,500
Additional information:
 - WhatsApp Number: +234 816 469 9784
Closer details:
Closer name: Caroline Onoja
Closer phone: 08160322891''';

  @override
  void initState() {
    super.initState();
    if (widget.initialText != null && widget.initialText!.isNotEmpty) {
      _textController.text = widget.initialText!;
      WidgetsBinding.instance.addPostFrameCallback((_) => _onRawTextChanged());
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _customerNameCtrl.dispose();
    _customerPhoneCtrl.dispose();
    _customerAltPhoneCtrl.dispose();
    _addressCtrl.dispose();
    _notesCtrl.dispose();
    _orderNumberCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  void _onRawTextChanged() {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      setState(() {
        _parsedOrder = null;
      });
      return;
    }

    final catalog = ref.read(productCatalogProvider);
    final parsed = SmartOrderParserService.parse(text, catalogProducts: catalog.products);

    setState(() {
      _parsedOrder = parsed;
      _orderNumberCtrl.text = parsed.orderNumber ?? '';
      _customerNameCtrl.text = parsed.customerName;
      _customerPhoneCtrl.text = parsed.phoneNumber;
      _customerAltPhoneCtrl.text = parsed.whatsappNumber ?? '';
      _addressCtrl.text = parsed.customerAddress;
      _notesCtrl.text = parsed.additionalInformation ?? '';
      _amountCtrl.text = parsed.amountToCollect.toStringAsFixed(0);

      _selectedState = parsed.state;
      _availableLgas = LocationLookupService.getLgasForState(_selectedState);
      if (_availableLgas.contains(parsed.lga)) {
        _selectedLga = parsed.lga;
      } else if (_availableLgas.isNotEmpty) {
        _selectedLga = _availableLgas.first;
      } else {
        _selectedLga = null;
      }

      // Match product & package
      if (parsed.items.isNotEmpty) {
        final firstItem = parsed.items.first;
        _quantity = firstItem.quantity;
        _selectedProduct = firstItem.matchedProduct;
        _selectedPackage = firstItem.matchedPackage;

        // If no catalog product matched, try finding by name or default
        if (_selectedProduct == null && catalog.products.isNotEmpty) {
          final cleanPName = firstItem.productName.toLowerCase();
          _selectedProduct = catalog.products.where((p) =>
              p.name.toLowerCase().contains(cleanPName) ||
              cleanPName.contains(p.name.toLowerCase())).firstOrNull;
          _selectedProduct ??= catalog.products.first;
        }
      }
    });
  }

  Future<void> _pasteFromClipboard() async {
    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    final text = clipboardData?.text;
    if (text != null && text.isNotEmpty) {
      _textController.text = text;
      _onRawTextChanged();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Clipboard is empty or does not contain text.')),
        );
      }
    }
  }

  void _loadSampleText() {
    _textController.text = sampleOrderText;
    _onRawTextChanged();
  }

  void _onStateChanged(String? newState) {
    if (newState == null || newState == _selectedState) return;
    setState(() {
      _selectedState = newState;
      _availableLgas = LocationLookupService.getLgasForState(newState);
      if (_availableLgas.isNotEmpty) {
        _selectedLga = _availableLgas.first;
      } else {
        _selectedLga = null;
      }
    });
  }

  Future<void> _submitParsedOrder() async {
    if (_parsedOrder == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please paste a structured WhatsApp order first.')),
      );
      return;
    }

    final custName = _customerNameCtrl.text.trim();
    final custPhone = _customerPhoneCtrl.text.trim();
    final custAddress = _addressCtrl.text.trim();

    if (custPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Customer phone number is required.')),
      );
      return;
    }

    if (custAddress.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Delivery address is required.')),
      );
      return;
    }

    if (_selectedLga == null || _selectedLga!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a valid Delivery LGA.')),
      );
      return;
    }

    final catalog = ref.read(productCatalogProvider);
    final fallbackProduct = _selectedProduct ??
        (catalog.products.isNotEmpty ? catalog.products.first : null);
    final prodId = fallbackProduct?.id ?? 'prod-${DateTime.now().millisecondsSinceEpoch}';
    final prodName = fallbackProduct?.name ??
        (_parsedOrder!.items.isNotEmpty ? _parsedOrder!.items.first.productName : 'Standard Product');

    final parsedAmount = double.tryParse(_amountCtrl.text.replaceAll(',', '')) ?? _parsedOrder!.amountToCollect;

    setState(() => _isSubmitting = true);
    try {
      final authUser = ref.read(authProvider).user;
      final isCloser = authUser?.isCloser == true;

      // Closer attribution: use logged-in closer or parsed closer details
      final closerId = isCloser
          ? (authUser?.closerId ?? authUser?.id)
          : null;
      final closerName = isCloser
          ? authUser?.fullName
          : (_parsedOrder?.closerName?.isNotEmpty == true ? _parsedOrder!.closerName : null);
      final closerCode = isCloser
          ? authUser?.closerCode
          : null;
      final closerAvatarUrl = isCloser ? authUser?.avatarUrl : null;

      final customOrderNo = _orderNumberCtrl.text.trim().isNotEmpty
          ? _orderNumberCtrl.text.trim()
          : _parsedOrder?.orderNumber;

      final createdOrder = await ref.read(clientPortalProvider.notifier).createOrder(
        customerName: custName.isNotEmpty ? custName : 'Customer',
        customerPhone: custPhone,
        customerAltPhone: _customerAltPhoneCtrl.text.trim().isNotEmpty
            ? _customerAltPhoneCtrl.text.trim()
            : null,
        deliveryState: _selectedState,
        deliveryLga: _selectedLga!,
        deliveryAddress: custAddress,
        productId: prodId,
        productName: prodName,
        quantity: _quantity > 0 ? _quantity : 1,
        paidQuantity: _selectedPackage?.paidQuantity ?? _quantity,
        freeQuantity: _selectedPackage?.freeQuantity ?? 0,
        sourceWarehouse: 'Stores - NL',
        totalAmount: parsedAmount > 0 ? parsedAmount : 21500.0,
        packageId: _selectedPackage?.id,
        packageName: _selectedPackage?.packageName,
        paymentType: _paymentType,
        autoAssignRider: true,
        closerId: closerId,
        closerName: closerName,
        closerCode: closerCode,
        closerAvatarUrl: closerAvatarUrl,
        notes: _notesCtrl.text.trim().isNotEmpty ? _notesCtrl.text.trim() : null,
        customOrderNumber: customOrderNo,
      );

      if (mounted) {
        Navigator.of(context).pop();
        final successMsg = createdOrder.deliveryAgentName != null
            ? 'Order ${createdOrder.orderNumber} created & auto-assigned live to ${createdOrder.deliveryAgentName} (${createdOrder.deliveryLga})!'
            : 'Order ${createdOrder.orderNumber} created & sent live to ${createdOrder.distributionCenterName ?? "DC Hub"} unassigned pool for rider dispatch!';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF0D9488),
            duration: const Duration(seconds: 4),
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    successMsg,
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.danger,
            content: Text('Error creating order from WhatsApp text: $e'),
          ),
        );
      }
    }
  }

  void _openInFullForm() {
    Navigator.of(context).pop();
    ClientCreateOrderModal.show(
      context,
      product: _selectedProduct,
      package: _selectedPackage,
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final isCompact = mediaQuery.size.width < 650;
    final currencyFmt = NumberFormat.currency(locale: 'en_NG', symbol: '₦', decimalDigits: 0);

    final dcState = ref.watch(dcConsoleProvider);
    final routingPreview = _parsedOrder != null
        ? OrderRoutingService.routeOrder(
            order: OrderEntity(
              id: 'preview',
              orderNumber: _orderNumberCtrl.text.trim().isNotEmpty ? _orderNumberCtrl.text.trim() : 'PREVIEW',
              customerName: _customerNameCtrl.text.trim().isNotEmpty ? _customerNameCtrl.text.trim() : 'Customer',
              customerPhone: _customerPhoneCtrl.text.trim().isNotEmpty ? _customerPhoneCtrl.text.trim() : '08000000000',
              deliveryState: _selectedState,
              deliveryCity: _selectedLga ?? 'AMAC',
              deliveryAddress: _addressCtrl.text,
              lga: _selectedLga,
              status: 'pending_dispatch',
              quantity: _quantity,
              basePrice: double.tryParse(_amountCtrl.text) ?? 21500.0,
              upsellAmount: 0.0,
              totalAmount: double.tryParse(_amountCtrl.text) ?? 21500.0,
              paymentType: _paymentType,
              paymentStatus: 'pending',
              createdAt: DateTime.now(),
            ),
            distributionCenters: dcState.distributionCenters,
            drivers: dcState.drivers,
            stockAllocations: const [],
          )
        : null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: EdgeInsets.symmetric(
        horizontal: isCompact ? 12 : 24,
        vertical: isCompact ? 16 : 24,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 820,
          maxHeight: mediaQuery.size.height * 0.92,
        ),
        child: Column(
          children: [
            // Modal Header
            Container(
              padding: EdgeInsets.symmetric(horizontal: isCompact ? 16 : 24, vertical: 16),
              decoration: const BoxDecoration(
                color: Color(0xFF0F172A),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D9488).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.paste_rounded, color: Color(0xFF2DD4BF), size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Smart WhatsApp / CRM Order Importer',
                          style: GoogleFonts.inter(
                            fontSize: isCompact ? 16 : 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Paste text copied from WhatsApp/CRM to convert into system order',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white70),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Modal Body
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(isCompact ? 14 : 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Quick Action Bar
                    Row(
                      children: [
                        FilledButton.icon(
                          onPressed: _pasteFromClipboard,
                          icon: const Icon(Icons.content_paste_go_rounded, size: 18),
                          label: const Text('Paste from Clipboard'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF0D9488),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: _loadSampleText,
                          icon: const Icon(Icons.auto_awesome_rounded, size: 16, color: Color(0xFFF37021)),
                          label: Text(
                            'Load Sample',
                            style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFFF37021)),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFF37021)),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                        const Spacer(),
                        if (_textController.text.isNotEmpty)
                          TextButton.icon(
                            onPressed: () {
                              _textController.clear();
                              _onRawTextChanged();
                            },
                            icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Colors.red),
                            label: const Text('Clear', style: TextStyle(color: Colors.red, fontSize: 12)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Paste Box
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _parsedOrder != null ? const Color(0xFF0D9488) : const Color(0xFFCBD5E1),
                          width: _parsedOrder != null ? 1.5 : 1,
                        ),
                      ),
                      child: TextField(
                        controller: _textController,
                        maxLines: 6,
                        onChanged: (_) => _onRawTextChanged(),
                        style: GoogleFonts.firaCode(fontSize: 12, color: const Color(0xFF1E293B)),
                        decoration: InputDecoration(
                          hintText: 'Paste formatted WhatsApp order block here...\n\nExample:\nOrder number: Novacare Ltd-CRM-ORD-10-009197\nCustomer name: +234 816 ...\nCustomer address: ...\nState: Bayelsa\nDetails of products: - RESPIRA LUNG TEA x1 ...\nAmount to collect: NGN 21,500',
                          hintStyle: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
                          contentPadding: const EdgeInsets.all(12),
                          border: InputBorder.none,
                        ),
                      ),
                    ),

                    if (_parsedOrder == null && _textController.text.isEmpty) ...[
                      const SizedBox(height: 24),
                      Center(
                        child: Column(
                          children: [
                            Icon(Icons.mark_chat_unread_rounded, size: 48, color: Colors.grey.shade400),
                            const SizedBox(height: 8),
                            Text(
                              'Paste order text from WhatsApp or CRM above to begin',
                              style: GoogleFonts.inter(color: Colors.grey.shade600, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],

                    if (_parsedOrder != null) ...[
                      const SizedBox(height: 18),

                      // Warnings Bar (e.g. Address is phone number or LGA auto-fallback)
                      if (_parsedOrder!.warnings.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.5)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.warning_amber_rounded, color: Color(0xFFB45309), size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Review Required Notice',
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFFB45309),
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              ..._parsedOrder!.warnings.map((w) => Padding(
                                    padding: const EdgeInsets.only(left: 28, bottom: 4),
                                    child: Text(
                                      '• $w',
                                      style: GoogleFonts.inter(
                                        color: const Color(0xFF92400E),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  )),
                            ],
                          ),
                        ),

                      // Parsed Fields Review Card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0D9488).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'Parsed Order Summary',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF0D9488),
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                if (_parsedOrder!.orderNumber != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'CRM ID: ${_parsedOrder!.orderNumber}',
                                      style: GoogleFonts.firaCode(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF475569),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Order Number & Amount
                            Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: _buildFormField(
                                    label: 'Order Reference / CRM Number',
                                    controller: _orderNumberCtrl,
                                    prefixIcon: Icons.tag_rounded,
                                    hintText: 'e.g. Novacare Ltd-CRM-ORD-10-009197',
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  flex: 2,
                                  child: _buildFormField(
                                    label: 'Amount to Collect (COD ₦)',
                                    controller: _amountCtrl,
                                    prefixIcon: Icons.payments_outlined,
                                    keyboardType: TextInputType.number,
                                    hintText: '21500',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            // Customer Name & Phone
                            Row(
                              children: [
                                Expanded(
                                  child: _buildFormField(
                                    label: 'Customer Name',
                                    controller: _customerNameCtrl,
                                    prefixIcon: Icons.person_outline_rounded,
                                    hintText: 'Customer Name',
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildFormField(
                                    label: 'Customer Phone',
                                    controller: _customerPhoneCtrl,
                                    prefixIcon: Icons.phone_outlined,
                                    keyboardType: TextInputType.phone,
                                    hintText: '08164699784',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            // Alternate WhatsApp Phone
                            _buildFormField(
                              label: 'WhatsApp Phone (Optional)',
                              controller: _customerAltPhoneCtrl,
                              prefixIcon: Icons.chat_outlined,
                              keyboardType: TextInputType.phone,
                              hintText: 'WhatsApp Contact',
                            ),
                            const SizedBox(height: 14),

                            // Delivery Address (With warning banner if suspicious)
                            _buildFormField(
                              label: 'Delivery Street Address',
                              controller: _addressCtrl,
                              prefixIcon: Icons.location_on_outlined,
                              hintText: 'House / Street / Landmark Address',
                              isHighlighted: _parsedOrder!.isAddressSuspicious,
                            ),
                            const SizedBox(height: 14),

                            // State & LGA Selectors
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'State',
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF475569),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12),
                                        decoration: BoxDecoration(
                                          border: Border.all(color: const Color(0xFFCBD5E1)),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: DropdownButtonHideUnderline(
                                          child: DropdownButton<String>(
                                            isExpanded: true,
                                            value: LocationLookupService.getAllStates().contains(_selectedState)
                                                ? _selectedState
                                                : LocationLookupService.getAllStates().first,
                                            items: LocationLookupService.getAllStates()
                                                .map((s) => DropdownMenuItem(
                                                      value: s,
                                                      child: Text(s, style: GoogleFonts.inter(fontSize: 13)),
                                                    ))
                                                .toList(),
                                            onChanged: _onStateChanged,
                                          ),
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
                                      Text(
                                        'LGA / City',
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF475569),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12),
                                        decoration: BoxDecoration(
                                          border: Border.all(color: const Color(0xFFCBD5E1)),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: DropdownButtonHideUnderline(
                                          child: DropdownButton<String>(
                                            isExpanded: true,
                                            value: _availableLgas.contains(_selectedLga) ? _selectedLga : null,
                                            hint: Text('Select LGA', style: GoogleFonts.inter(fontSize: 13)),
                                            items: _availableLgas
                                                .map((l) => DropdownMenuItem(
                                                      value: l,
                                                      child: Text(l, style: GoogleFonts.inter(fontSize: 13)),
                                                    ))
                                                .toList(),
                                            onChanged: (val) {
                                              if (val != null) setState(() => _selectedLga = val);
                                            },
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            // Product details match
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0D9488).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.inventory_2_rounded, color: Color(0xFF0D9488), size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _selectedProduct?.name ??
                                              (_parsedOrder!.items.isNotEmpty
                                                  ? _parsedOrder!.items.first.productName
                                                  : 'RESPIRA LUNG TEA'),
                                          style: GoogleFonts.inter(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: const Color(0xFF0F172A),
                                          ),
                                        ),
                                        Text(
                                          'Quantity: $_quantity  •  Total: ${currencyFmt.format(double.tryParse(_amountCtrl.text) ?? _parsedOrder!.amountToCollect)}',
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            color: const Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (_selectedProduct != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFD1FAE5),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        'Catalog Matched',
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

                            // Delivery Notes
                            _buildFormField(
                              label: 'Additional Delivery Notes',
                              controller: _notesCtrl,
                              prefixIcon: Icons.notes_rounded,
                              hintText: 'e.g. Call before dispatch, landmark notes',
                            ),

                            // Closer Attribution
                            if (_parsedOrder!.closerName != null || _parsedOrder!.closerPhone != null) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.badge_outlined, size: 16, color: Color(0xFF475569)),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Closer: ${_parsedOrder!.closerName ?? "N/A"} (${_parsedOrder!.closerPhone ?? "N/A"})',
                                      style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF334155), fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            // Live Dispatch Preview
                            if (routingPreview != null) ...[
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFECFDF5),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFA7F3D0)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.hub_rounded, color: Color(0xFF059669), size: 20),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Dispatch Target: ${routingPreview.distributionCenter?.name ?? "Auto-routing DC Hub"}',
                                            style: GoogleFonts.inter(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                              color: const Color(0xFF065F46),
                                            ),
                                          ),
                                          Text(
                                            routingPreview.driver != null
                                                ? 'Rider Available: ${routingPreview.driver!.name} (${routingPreview.driver!.driverCode})'
                                                : 'Will queue in ${routingPreview.distributionCenter?.name ?? "DC"} unassigned pool for quick dispatch.',
                                            style: GoogleFonts.inter(
                                              fontSize: 11,
                                              color: const Color(0xFF047857),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Modal Footer Actions
            Container(
              padding: EdgeInsets.symmetric(horizontal: isCompact ? 16 : 24, vertical: 14),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  OutlinedButton(
                    onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text('Cancel', style: GoogleFonts.inter(color: const Color(0xFF64748B))),
                  ),
                  const SizedBox(width: 8),
                  if (_parsedOrder != null)
                    TextButton.icon(
                      onPressed: _isSubmitting ? null : _openInFullForm,
                      icon: const Icon(Icons.edit_note_rounded, size: 18, color: Color(0xFF0D9488)),
                      label: Text(
                        'Open in Full Form',
                        style: GoogleFonts.inter(color: const Color(0xFF0D9488), fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: (_isSubmitting || _parsedOrder == null) ? null : _submitParsedOrder,
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.check_circle_rounded, size: 18),
                    label: Text(
                      _isSubmitting ? 'Creating Order...' : 'Confirm & Create Order',
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF0D9488),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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

  Widget _buildFormField({
    required String label,
    required TextEditingController controller,
    required IconData prefixIcon,
    String? hintText,
    TextInputType keyboardType = TextInputType.text,
    bool isHighlighted = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isHighlighted ? const Color(0xFFB45309) : const Color(0xFF475569),
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF1E293B)),
          decoration: InputDecoration(
            prefixIcon: Icon(prefixIcon, size: 18, color: isHighlighted ? const Color(0xFFF59E0B) : const Color(0xFF64748B)),
            hintText: hintText,
            hintStyle: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
            filled: true,
            fillColor: isHighlighted ? const Color(0xFFFFFBEB) : Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: isHighlighted ? const Color(0xFFF59E0B) : const Color(0xFFCBD5E1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: isHighlighted ? const Color(0xFFF59E0B) : const Color(0xFFCBD5E1),
                width: isHighlighted ? 1.5 : 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: isHighlighted ? const Color(0xFFF59E0B) : const Color(0xFF0D9488),
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
