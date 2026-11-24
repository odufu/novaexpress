import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/widgets/nova_searchable_picker.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../stock/presentation/providers/stock_provider.dart';
import '../../domain/entities/merchant_inventory_models.dart';
import '../providers/merchant_inventory_provider.dart';

class MerchantCreateInboundRequestModal extends ConsumerStatefulWidget {
  const MerchantCreateInboundRequestModal({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const MerchantCreateInboundRequestModal(),
    );
  }

  @override
  ConsumerState<MerchantCreateInboundRequestModal> createState() =>
      _MerchantCreateInboundRequestModalState();
}

class _MerchantCreateInboundRequestModalState
    extends ConsumerState<MerchantCreateInboundRequestModal> {
  final _formKey = GlobalKey<FormState>();

  String? _selectedProductId;
  String _selectedDcId = 'dc-abuja-central';
  String _selectedDcName = 'Abuja Central DC';

  final _quantityCtrl = TextEditingController(text: '500');
  final _waybillCtrl = TextEditingController();
  final _driverNameCtrl = TextEditingController();
  final _driverPhoneCtrl = TextEditingController();
  final _plateNumberCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  bool _isSubmitting = false;

  final List<Map<String, String>> _availableDcs = const [
    {
      'id': 'dc-abuja-central',
      'name': 'Abuja Central DC',
      'location': 'Plot 1042 Wuse Zone 2, Abuja',
    },
    {
      'id': 'dc-lagos-grand',
      'name': 'Lagos Grand Hub',
      'location': 'Oregun Industrial Estate, Ikeja, Lagos',
    },
    {
      'id': 'dc-kano-hub',
      'name': 'Kano Hub',
      'location': 'Bompai Industrial Area, Kano',
    },
    {
      'id': 'dc-ph-hub',
      'name': 'Port Harcourt Hub',
      'location': 'Trans-Amadi Industrial Layout, Rivers',
    },
  ];

  @override
  void initState() {
    super.initState();
    final randomSuffix = (1000 + math.Random().nextInt(9000)).toString();
    _waybillCtrl.text = 'WB-NOVA-${DateTime.now().year}-$randomSuffix';
  }

  @override
  void dispose() {
    _quantityCtrl.dispose();
    _waybillCtrl.dispose();
    _driverNameCtrl.dispose();
    _driverPhoneCtrl.dispose();
    _plateNumberCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    final qty = int.tryParse(_quantityCtrl.text.trim()) ?? 0;
    if (qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFFEF4444),
          content: Text('Please enter a valid physical quantity to supply (at least 1 unit).'),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final merchantInv = ref.read(merchantInventoryProvider);
      final products = merchantInv.products;
      final selectedProd = products.firstWhere(
        (p) => p.id == _selectedProductId || p.sku == _selectedProductId,
        orElse: () => products.first,
      );

      // 1. Dispatch into Merchant Inventory State
      final shipment = await ref.read(merchantInventoryProvider.notifier).createInboundShipment(
            productId: selectedProd.id,
            targetDcId: _selectedDcId,
            targetDcName: _selectedDcName,
            expectedQuantity: qty,
            waybillNumber: _waybillCtrl.text.trim(),
            carrierDriverName: _driverNameCtrl.text.trim(),
            carrierPhone: _driverPhoneCtrl.text.trim(),
            carrierPlate: _plateNumberCtrl.text.trim(),
            notes: _notesCtrl.text.trim(),
          );

      // 2. Dispatch into Stock Remote DataSource / Stock Provider as client_supply
      try {
        final authState = ref.read(authProvider);
        final senderName = authState.user?.fullName ?? 'Merchant Stock Keeper';
        final senderId = authState.user?.id;

        await ref.read(stockProvider.notifier).dispatchClientSupply(
              clientId: merchantInv.merchantId,
              dcId: _selectedDcId,
              items: [
                {
                  'product_id': selectedProd.id,
                  'product_name': selectedProd.name,
                  'sku': selectedProd.sku,
                  'quantity': qty,
                }
              ],
              senderId: senderId,
              senderName: senderName,
              notes: 'Waybill: ${shipment.waybillNumber} • Driver: ${_driverNameCtrl.text.trim()} (${_plateNumberCtrl.text.trim()})',
            );
      } catch (e) {
        debugPrint('[MERCHANT_INBOUND] Note: stockProvider sync background: $e');
      }

      if (!mounted) return;
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF059669),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Inbound Request ${shipment.waybillNumber} created! En route to $_selectedDcName.',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFEF4444),
          content: Text('Error creating inbound request: $e'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final merchantInv = ref.watch(merchantInventoryProvider);
    final products = merchantInv.products;

    if (_selectedProductId == null && products.isNotEmpty) {
      _selectedProductId = products.first.id;
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title and Subtitle
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.local_shipping_rounded,
                      color: Color(0xFF0284C7),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Create Inbound Stock Request',
                          style: GoogleFonts.inter(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          'Dispatch product consignment from factory to NovaXpress DC',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),

              // Product Selection (Searchable Mobile Picker)
              NovaSearchableSelectField<String>(
                label: 'Select Product SKU *',
                placeholder: 'Tap to select product SKU...',
                value: _selectedProductId,
                prefixIcon: Icons.inventory_2_outlined,
                brandColor: const Color(0xFF0284C7),
                pickerTitle: 'Select Product SKU',
                pickerSubtitle: 'Choose product consignment to supply to DC',
                options: products.map((p) {
                  return NovaPickerOption<String>(
                    value: p.id,
                    title: p.name,
                    subtitle: 'SKU: ${p.sku} • Current System Stock: ${p.totalSystemStock} pcs',
                    badgeText: p.sku,
                    badgeColor: const Color(0xFF0284C7),
                    icon: Icons.inventory_2_outlined,
                    trailingText: '${p.totalSystemStock} pcs',
                    trailingTextColor: const Color(0xFF0284C7),
                    searchTerms: [p.name, p.sku, p.category],
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedProductId = val);
                },
              ),
              const SizedBox(height: 14),

              // Target DC Selection (Searchable Mobile Picker)
              NovaSearchableSelectField<String>(
                label: 'Destination Distribution Center (DC) *',
                placeholder: 'Tap to select destination DC warehouse...',
                value: _selectedDcId,
                prefixIcon: Icons.warehouse_rounded,
                brandColor: const Color(0xFF7C3AED),
                pickerTitle: 'Destination Distribution Center (DC)',
                pickerSubtitle: 'Choose target receiving warehouse hub',
                options: _availableDcs.map((dc) {
                  return NovaPickerOption<String>(
                    value: dc['id']!,
                    title: dc['name']!,
                    subtitle: dc['location']!,
                    badgeText: 'DC HUB',
                    badgeColor: const Color(0xFF7C3AED),
                    icon: Icons.warehouse_rounded,
                    searchTerms: [dc['name']!, dc['location']!],
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    final found = _availableDcs.firstWhere((d) => d['id'] == val);
                    setState(() {
                      _selectedDcId = val;
                      _selectedDcName = found['name']!;
                    });
                  }
                },
              ),
              const SizedBox(height: 16),

              // Quantity & Waybill
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Units Shipped *',
                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _quantityCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            hintText: 'e.g. 500',
                            filled: true,
                            fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) return 'Required';
                            if (int.tryParse(val.trim()) == null) return 'Invalid number';
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Waybill / Ref Number *',
                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _waybillCtrl,
                          decoration: InputDecoration(
                            hintText: 'e.g. WB-NOVA-2026-081',
                            filled: true,
                            fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                          validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Carrier Driver & Phone
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Driver / Carrier Name',
                          style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _driverNameCtrl,
                          decoration: InputDecoration(
                            hintText: 'e.g. Ibrahim Musa',
                            filled: true,
                            fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Driver Phone',
                          style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _driverPhoneCtrl,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            hintText: '080...',
                            filled: true,
                            fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Vehicle License Plate
              Text(
                'Vehicle Plate Number',
                style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _plateNumberCtrl,
                decoration: InputDecoration(
                  hintText: 'e.g. ABJ-452-XY',
                  filled: true,
                  fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 12),

              // Notes / Special Instructions
              Text(
                'Supplier Notes & Quality Instructions',
                style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _notesCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'e.g. Batch #B402, fragile amber bottles, keep upright',
                  filled: true,
                  fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 22),

              // Submit Action
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0284C7),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  onPressed: _isSubmitting ? null : _handleSubmit,
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.send_rounded, size: 20),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'Dispatch Inbound Consignment',
                                style: GoogleFonts.inter(fontSize: 14.5, fontWeight: FontWeight.w700),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
