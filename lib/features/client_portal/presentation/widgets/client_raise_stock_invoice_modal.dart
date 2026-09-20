import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../dc_console/domain/entities/product_package.dart';
import '../../../dc_console/presentation/providers/dc_console_provider.dart';
import '../../../dc_console/presentation/providers/product_catalog_provider.dart';
import '../../../stock/presentation/providers/stock_provider.dart';
import '../../domain/entities/client_stock_invoice.dart';
import '../providers/client_portal_provider.dart';
import 'client_add_supplier_modal.dart';

class ClientRaiseStockInvoiceModal extends ConsumerStatefulWidget {
  final CatalogProduct? initialProduct;
  final String? initialSupplierId;

  const ClientRaiseStockInvoiceModal({
    super.key,
    this.initialProduct,
    this.initialSupplierId,
  });

  static Future<ClientStockInvoice?> show(
    BuildContext context, {
    CatalogProduct? initialProduct,
    String? initialSupplierId,
  }) {
    return showDialog<ClientStockInvoice>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ClientRaiseStockInvoiceModal(
        initialProduct: initialProduct,
        initialSupplierId: initialSupplierId,
      ),
    );
  }

  @override
  ConsumerState<ClientRaiseStockInvoiceModal> createState() => _ClientRaiseStockInvoiceModalState();
}

class _InvoiceItemDraft {
  String? productId;
  String productName;
  String sku;
  int quantity;
  double unitCost;
  double packagingCost;
  double freightCost;
  double handlingCost;

  _InvoiceItemDraft({
    this.productId,
    required this.productName,
    required this.sku,
    this.quantity = 100,
    this.unitCost = 1500.0,
    this.packagingCost = 250.0,
    this.freightCost = 150.0,
    this.handlingCost = 50.0,
  });

  double get landedCostPerUnit => unitCost + packagingCost + freightCost + handlingCost;
  double get lineTotalLandedCost => landedCostPerUnit * quantity;
  double get lineBaseCost => unitCost * quantity;
  double get linePackagingCost => packagingCost * quantity;
  double get lineFreightCost => freightCost * quantity;
  double get lineHandlingCost => handlingCost * quantity;
}

class _ClientRaiseStockInvoiceModalState extends ConsumerState<ClientRaiseStockInvoiceModal> {
  final _formKey = GlobalKey<FormState>();
  final _currencyFormat = NumberFormat('#,##0.00', 'en_US');

  String? _selectedSupplierId;
  String _invoiceNumber = '';
  String? _selectedDcId = '22222222-2222-4222-8222-222222222222';
  String _targetWarehouse = 'Wuse Central Distribution Hub';
  String _paymentStatus = 'unpaid';
  final _notesController = TextEditingController();
  final _waybillRefController = TextEditingController();

  final List<_InvoiceItemDraft> _items = [];
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final randomSuffix = (now.millisecondsSinceEpoch % 9000 + 1000).toString();
    _invoiceNumber = 'SI-${now.year}-${now.month.toString().padLeft(2, '0')}-$randomSuffix';
    _waybillRefController.text = 'WB-${now.year}-$randomSuffix';

    // Prepopulate with at least one item from catalog or initial product
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = ref.read(clientPortalProvider);

      // Supplier selection priority
      if (widget.initialSupplierId != null && widget.initialSupplierId!.isNotEmpty) {
        _selectedSupplierId = widget.initialSupplierId;
      } else if (widget.initialProduct?.preferredSupplierId != null && widget.initialProduct!.preferredSupplierId!.isNotEmpty) {
        _selectedSupplierId = widget.initialProduct!.preferredSupplierId;
      } else if (state.suppliers.isNotEmpty) {
        _selectedSupplierId = state.suppliers.first.id;
      }

      if (widget.initialProduct != null) {
        final p = widget.initialProduct!;
        setState(() {
          _items.add(
            _InvoiceItemDraft(
              productId: p.id,
              productName: p.name,
              sku: p.sku.isNotEmpty ? p.sku : 'PROD-01',
              quantity: 250,
              unitCost: p.costPrice > 0 ? p.costPrice : 1500.0,
              packagingCost: 250.0,
              freightCost: 150.0,
              handlingCost: 50.0,
            ),
          );
        });
      } else if (state.products.isNotEmpty) {
        final p = state.products.first;
        setState(() {
          _items.add(
            _InvoiceItemDraft(
              productId: p.id,
              productName: p.name,
              sku: p.sku.isNotEmpty ? p.sku : 'PROD-01',
              quantity: 250,
              unitCost: p.costPrice > 0 ? p.costPrice : 1500.0,
              packagingCost: 250.0,
              freightCost: 150.0,
              handlingCost: 50.0,
            ),
          );
        });
      } else {
        setState(() {
          _items.add(
            _InvoiceItemDraft(
              productName: 'Grazer Herbal Tea (20 Tea Bags)',
              sku: 'GRAZER-TEA-20',
              quantity: 250,
              unitCost: 1500.0,
              packagingCost: 250.0,
              freightCost: 150.0,
              handlingCost: 50.0,
            ),
          );
        });
      }
    });
  }

  @override
  void dispose() {
    _notesController.dispose();
    _waybillRefController.dispose();
    super.dispose();
  }

  int get _totalQuantity => _items.fold(0, (sum, i) => sum + i.quantity);
  double get _totalBaseCost => _items.fold(0.0, (sum, i) => sum + i.lineBaseCost);
  double get _totalPackagingCost => _items.fold(0.0, (sum, i) => sum + i.linePackagingCost);
  double get _totalFreightCost => _items.fold(0.0, (sum, i) => sum + i.lineFreightCost);
  double get _totalHandlingCost => _items.fold(0.0, (sum, i) => sum + i.lineHandlingCost);
  double get _grandTotalLandedCost => _items.fold(0.0, (sum, i) => sum + i.lineTotalLandedCost);

  void _addNewItemRow() {
    final state = ref.read(clientPortalProvider);
    if (state.products.isNotEmpty) {
      // Pick next unused product if available
      final unused = state.products.where((p) => !_items.any((item) => item.productId == p.id)).toList();
      final p = unused.isNotEmpty ? unused.first : state.products.first;
      setState(() {
        _items.add(
          _InvoiceItemDraft(
            productId: p.id,
            productName: p.name,
            sku: p.sku.isNotEmpty ? p.sku : 'PROD-${_items.length + 1}',
            quantity: 100,
            unitCost: 1800.0,
            packagingCost: 200.0,
            freightCost: 120.0,
            handlingCost: 40.0,
          ),
        );
      });
    } else {
      setState(() {
        _items.add(
          _InvoiceItemDraft(
            productName: 'Herbal Formulation Product #${_items.length + 1}',
            sku: 'HERB-${_items.length + 1}',
            quantity: 100,
            unitCost: 1800.0,
            packagingCost: 200.0,
            freightCost: 120.0,
            handlingCost: 40.0,
          ),
        );
      });
    }
  }

  Future<void> _submitInvoice() async {
    if (!_formKey.currentState!.validate()) return;
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFFEF4444),
          content: Text('Please add at least one product intake line item'),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final state = ref.read(clientPortalProvider);
      final supplier = state.suppliers.where((s) => s.id == _selectedSupplierId).firstOrNull;

      final invoiceItems = _items.map((draft) {
        return ClientStockInvoiceItem.calculate(
          productId: draft.productId,
          productName: draft.productName,
          productSku: draft.sku,
          quantity: draft.quantity,
          supplierUnitPrice: draft.unitCost,
          packagingCostPerUnit: draft.packagingCost,
          transportationCostPerUnit: draft.freightCost,
          handlingCostPerUnit: draft.handlingCost,
        );
      }).toList();

      final newInvoice = ClientStockInvoice(
        id: '',
        clientId: state.clientProfile.id,
        invoiceNumber: _invoiceNumber.trim(),
        supplierId: _selectedSupplierId,
        supplierName: supplier?.name ?? 'Direct Procurement Partner',
        destinationWarehouse: _targetWarehouse,
        entryDate: DateTime.now(),
        status: 'verified',
        paymentStatus: _paymentStatus,
        totalUnits: _totalQuantity,
        subtotalRawProductCost: _totalBaseCost,
        totalPackagingCost: _totalPackagingCost,
        totalTransportationCost: _totalFreightCost,
        totalHandlingClearingCost: _totalHandlingCost,
        grandTotalLandedCost: _grandTotalLandedCost,
        notes: _notesController.text.trim(),
        items: invoiceItems,
        createdAt: DateTime.now(),
      );

      final invoice = await ref.read(clientPortalProvider.notifier).raiseStockInvoice(
            invoice: newInvoice,
            items: invoiceItems,
          );

      // Automatically register the corresponding physical consignment handshake to the destination DC
      try {
        final authState = ref.read(authProvider);
        final senderName = authState.user?.fullName ??
            (state.clientProfile.companyName.isNotEmpty ? state.clientProfile.companyName : 'Merchant Procurement');

        final dcState = ref.read(dcConsoleProvider);
        final allDcs = dcState.distributionCenters.isNotEmpty
            ? dcState.distributionCenters
            : defaultDistributionCenters;
        final targetDc = allDcs.firstWhere(
          (d) => d.id == _selectedDcId,
          orElse: () => allDcs.where((d) =>
              _targetWarehouse.toLowerCase().contains(d.name.toLowerCase()) ||
              d.name.toLowerCase().contains(_targetWarehouse.toLowerCase())
          ).firstOrNull ?? allDcs.first,
        );

        final supplyItems = _items.map((i) {
          var pId = i.productId;
          if (pId == null || !RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$').hasMatch(pId)) {
            final catalog = ref.read(productCatalogProvider);
            final match = catalog.findProductBySku(i.sku) ?? catalog.findProductByName(i.productName);
            if (match != null && RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$').hasMatch(match.id)) {
              pId = match.id;
            }
          }
          return {
            'product_id': pId,
            'quantity': i.quantity,
            'notes': 'Intake bill: ${invoice.invoiceNumber}',
          };
        }).toList();

        await ref.read(stockProvider.notifier).dispatchClientSupply(
          clientId: state.clientProfile.id.isNotEmpty ? state.clientProfile.id : '00000000-0000-4000-8000-789382731303',
          dcId: targetDc.id,
          items: supplyItems,
          senderId: authState.user?.id,
          senderName: senderName,
          notes: 'Procurement Intake from ${supplier?.name ?? "Vendor"} (Invoice: ${invoice.invoiceNumber})',
        );

        // Immediate background refresh of DC inbound stock transfers
        await ref.read(stockProvider.notifier).fetchStockTransfers(dcId: targetDc.id);
      } catch (consignmentErr) {
        debugPrint('[INTAKE_MODAL] ℹ️ Handshake consignment creation notice: $consignmentErr');
      }

      if (mounted) {
        Navigator.of(context).pop(invoice);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Stock Entry Invoice "${invoice.invoiceNumber}" posted! ₦${_currencyFormat.format(invoice.grandTotalLandedCost)} added to inventory ledger.',
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFEF4444),
            content: Text('Failed to raise stock invoice: $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Widget _buildFieldPair({
    required Widget first,
    required Widget second,
    required bool isCompact,
    int firstFlex = 3,
    int secondFlex = 2,
  }) {
    if (isCompact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          first,
          const SizedBox(height: 14),
          second,
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: firstFlex, child: first),
        const SizedBox(width: 14),
        Expanded(flex: secondFlex, child: second),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = ref.watch(clientPortalProvider);
    final dcState = ref.watch(dcConsoleProvider);
    final allDcs = dcState.distributionCenters.isNotEmpty
        ? dcState.distributionCenters
        : defaultDistributionCenters;
    final isCompact = MediaQuery.of(context).size.width < 640;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        width: 880,
        constraints: const BoxConstraints(maxHeight: 820),
        child: Column(
          children: [
            // Modal Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: BoxDecoration(
                color: const Color(0xFF0D9488).withValues(alpha: 0.08),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D9488).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.post_add_rounded, color: Color(0xFF0D9488), size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Raise Stock Intake & Goods Receipt Invoice',
                              style: GoogleFonts.inter(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0D9488).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Landed Cost Math',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF0D9488),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Record incoming shipments with itemized landed costs (base supplier + packaging + haulage)',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(0xFF64748B),
                          ),
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

            // Modal Body
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(isCompact ? 16 : 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Invoice Meta Bar (Supplier, Invoice Number, Target DC, Waybill)
                      Container(
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
                            _buildFieldPair(
                              isCompact: isCompact,
                              firstFlex: 3,
                              secondFlex: 2,
                              first: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      _buildLabel('Procurement Supplier *', isDark),
                                      InkWell(
                                        onTap: () async {
                                          final s = await ClientAddSupplierModal.show(context);
                                          if (s != null && mounted) {
                                            setState(() => _selectedSupplierId = s.id);
                                          }
                                        },
                                        child: Text(
                                          '+ New Supplier',
                                          style: GoogleFonts.inter(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: const Color(0xFF0D9488),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  DropdownButtonFormField<String>(
                                    value: state.suppliers.any((s) => s.id == _selectedSupplierId)
                                        ? _selectedSupplierId
                                        : (state.suppliers.isNotEmpty ? state.suppliers.first.id : null),
                                    isExpanded: true,
                                    dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                                    style: TextStyle(
                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                      fontSize: 13,
                                    ),
                                    decoration: _inputDecoration(
                                      hintText: 'Select Supplier',
                                      icon: Icons.business_rounded,
                                      isDark: isDark,
                                    ),
                                    items: state.suppliers.map((s) {
                                      return DropdownMenuItem(
                                        value: s.id,
                                        child: Text(
                                          '${s.name} (${s.category})',
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (val) => setState(() => _selectedSupplierId = val),
                                  ),
                                ],
                              ),
                              second: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildLabel('Invoice Bill Ref *', isDark),
                                  const SizedBox(height: 6),
                                  TextFormField(
                                    initialValue: _invoiceNumber,
                                    style: TextStyle(
                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                      fontSize: 13,
                                    ),
                                    decoration: _inputDecoration(
                                      hintText: 'INV-2026-09-001',
                                      icon: Icons.receipt_long_rounded,
                                      isDark: isDark,
                                    ),
                                    onChanged: (v) => _invoiceNumber = v,
                                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),

                            _buildFieldPair(
                              isCompact: isCompact,
                              firstFlex: 3,
                              secondFlex: 2,
                              first: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildLabel('Receiving Warehouse / Station Hub', isDark),
                                  const SizedBox(height: 6),
                                  DropdownButtonFormField<String>(
                                    value: allDcs.any((d) => d.id == _selectedDcId)
                                        ? _selectedDcId
                                        : (allDcs.isNotEmpty ? allDcs.first.id : null),
                                    isExpanded: true,
                                    dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                                    style: TextStyle(
                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                      fontSize: 13,
                                    ),
                                    decoration: _inputDecoration(
                                      hintText: 'Target Receiving Hub',
                                      icon: Icons.warehouse_rounded,
                                      isDark: isDark,
                                    ),
                                    items: allDcs.map((dc) {
                                      return DropdownMenuItem<String>(
                                        value: dc.id,
                                        child: Text(
                                          '${dc.name} (${dc.code})',
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (val) {
                                      if (val != null) {
                                        final dc = allDcs.firstWhere((d) => d.id == val);
                                        setState(() {
                                          _selectedDcId = val;
                                          _targetWarehouse = dc.name;
                                        });
                                      }
                                    },
                                  ),
                                ],
                              ),
                              second: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildLabel('Waybill / Consignment Ref', isDark),
                                  const SizedBox(height: 6),
                                  TextFormField(
                                    controller: _waybillRefController,
                                    style: TextStyle(
                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                      fontSize: 13,
                                    ),
                                    decoration: _inputDecoration(
                                      hintText: 'WB-2026-001',
                                      icon: Icons.local_shipping_rounded,
                                      isDark: isDark,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Line Items Table Section
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Stock Entry Line Items & Landed Cost Breakdown',
                                style: GoogleFonts.inter(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                              Text(
                                'Landed Cost / Unit = Base Supplier Cost + Packaging + Freight + Handling',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                          ElevatedButton.icon(
                            onPressed: _addNewItemRow,
                            icon: const Icon(Icons.add_rounded, size: 16),
                            label: Text(
                              '+ Add Product Item',
                              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0D9488),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Items List
                      ..._items.asMap().entries.map((entry) {
                        final index = entry.key;
                        final item = entry.value;
                        return _buildItemRowCard(index, item, isDark, state, isCompact);
                      }),
                      const SizedBox(height: 20),

                      // Financial Summary Banner
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF042F2E), Color(0xFF134E4A)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFF0D9488), width: 1.5),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.calculate_rounded, color: Color(0xFF2DD4BF), size: 22),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Consolidated Stock Intake Valuation',
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '${_items.length} Lines • $_totalQuantity Units',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            const Divider(color: Color(0xFF115E59), height: 1),
                            const SizedBox(height: 14),
                            if (isCompact)
                              Wrap(
                                spacing: 16,
                                runSpacing: 14,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  _buildSummaryMetric('Base Procurement', '₦${_currencyFormat.format(_totalBaseCost)}'),
                                  _buildSummaryMetric('Total Packaging', '₦${_currencyFormat.format(_totalPackagingCost)}'),
                                  _buildSummaryMetric('Haulage & Freight', '₦${_currencyFormat.format(_totalFreightCost)}'),
                                  _buildSummaryMetric('Handling & Port', '₦${_currencyFormat.format(_totalHandlingCost)}'),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2DD4BF).withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: const Color(0xFF2DD4BF)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'TOTAL LANDED COST',
                                          style: GoogleFonts.inter(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            color: const Color(0xFF5EEAD4),
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                        Text(
                                          '₦${_currencyFormat.format(_grandTotalLandedCost)}',
                                          style: GoogleFonts.inter(
                                            fontSize: 17,
                                            fontWeight: FontWeight.w900,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              )
                            else
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  _buildSummaryMetric('Base Procurement', '₦${_currencyFormat.format(_totalBaseCost)}'),
                                  _buildSummaryMetric('Total Packaging', '₦${_currencyFormat.format(_totalPackagingCost)}'),
                                  _buildSummaryMetric('Haulage & Freight', '₦${_currencyFormat.format(_totalFreightCost)}'),
                                  _buildSummaryMetric('Handling & Port', '₦${_currencyFormat.format(_totalHandlingCost)}'),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2DD4BF).withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: const Color(0xFF2DD4BF)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          'TOTAL LANDED COST',
                                          style: GoogleFonts.inter(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            color: const Color(0xFF5EEAD4),
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                        Text(
                                          '₦${_currencyFormat.format(_grandTotalLandedCost)}',
                                          style: GoogleFonts.inter(
                                            fontSize: 17,
                                            fontWeight: FontWeight.w900,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Payment Status & Notes
                      _buildFieldPair(
                        isCompact: isCompact,
                        firstFlex: 1,
                        secondFlex: 1,
                        first: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel('Payment Status to Supplier', isDark),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<String>(
                              value: _paymentStatus,
                              dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                              style: TextStyle(
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                                fontSize: 13,
                              ),
                              decoration: _inputDecoration(
                                hintText: 'Payment Status',
                                icon: Icons.payment_rounded,
                                isDark: isDark,
                              ),
                              items: const [
                                DropdownMenuItem(value: 'unpaid', child: Text('Unpaid (Accounts Payable)')),
                                DropdownMenuItem(value: 'partially_paid', child: Text('Partially Paid')),
                                DropdownMenuItem(value: 'paid', child: Text('Fully Paid')),
                              ],
                              onChanged: (val) {
                                if (val != null) setState(() => _paymentStatus = val);
                              },
                            ),
                          ],
                        ),
                        second: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel('Batch Notes & Quality Control', isDark),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _notesController,
                              style: TextStyle(
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                                fontSize: 13,
                              ),
                              decoration: _inputDecoration(
                                hintText: 'e.g. Lab tested, packaging verified...',
                                icon: Icons.notes_rounded,
                                isDark: isDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Modal Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0B1120) : const Color(0xFFF8FAFC),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18)),
                border: Border(
                  top: BorderSide(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Note: Posting recalculates weighted average valuation rates in live inventory ledger.',
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        color: const Color(0xFF64748B),
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text('Cancel', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : _submitInvoice,
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.check_circle_rounded, size: 18),
                    label: Text(
                      _isSubmitting ? 'Posting Ledger...' : 'Post Stock Entry & Landed Cost',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D9488),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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

  Widget _buildItemRowCard(int index, _InvoiceItemDraft item, bool isDark, ClientPortalState state, bool isCompact) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        children: [
          if (isCompact) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D9488).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Item #${index + 1}',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0D9488),
                    ),
                  ),
                ),
                if (_items.length > 1)
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 20),
                    tooltip: 'Remove Row',
                    onPressed: () => setState(() => _items.removeAt(index)),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            state.products.isNotEmpty
                ? DropdownButtonFormField<String>(
                    value: state.products.any((p) => p.id == item.productId)
                        ? item.productId
                        : state.products.first.id,
                    isExpanded: true,
                    dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                    style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                      fontSize: 13,
                    ),
                    decoration: _inputDecoration(hintText: 'Product', icon: Icons.inventory_2_rounded, isDark: isDark),
                    items: state.products.map((p) {
                      return DropdownMenuItem(
                        value: p.id,
                        child: Text('${p.name} (${p.sku})', overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        final match = state.products.firstWhere((p) => p.id == val);
                        setState(() {
                          item.productId = match.id;
                          item.productName = match.name;
                          item.sku = match.sku;
                        });
                      }
                    },
                  )
                : TextFormField(
                    initialValue: item.productName,
                    style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 13),
                    decoration: _inputDecoration(hintText: 'Product Name', icon: Icons.inventory_2_rounded, isDark: isDark),
                    onChanged: (v) => item.productName = v,
                  ),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: item.quantity.toString(),
              keyboardType: TextInputType.number,
              style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 13),
              decoration: _inputDecoration(hintText: 'Quantity (Units)', icon: Icons.numbers_rounded, isDark: isDark),
              onChanged: (v) {
                setState(() {
                  item.quantity = int.tryParse(v) ?? 0;
                });
              },
            ),
          ] else
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D9488).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '#${index + 1}',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0D9488),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Product Selection
                Expanded(
                  flex: 4,
                  child: state.products.isNotEmpty
                      ? DropdownButtonFormField<String>(
                          value: state.products.any((p) => p.id == item.productId)
                              ? item.productId
                              : state.products.first.id,
                          isExpanded: true,
                          dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                          style: TextStyle(
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                            fontSize: 13,
                          ),
                          decoration: _inputDecoration(hintText: 'Product', icon: Icons.inventory_2_rounded, isDark: isDark),
                          items: state.products.map((p) {
                            return DropdownMenuItem(
                              value: p.id,
                              child: Text('${p.name} (${p.sku})', overflow: TextOverflow.ellipsis),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              final match = state.products.firstWhere((p) => p.id == val);
                              setState(() {
                                item.productId = match.id;
                                item.productName = match.name;
                                item.sku = match.sku;
                              });
                            }
                          },
                        )
                      : TextFormField(
                          initialValue: item.productName,
                          style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 13),
                          decoration: _inputDecoration(hintText: 'Product Name', icon: Icons.inventory_2_rounded, isDark: isDark),
                          onChanged: (v) => item.productName = v,
                        ),
                ),
                const SizedBox(width: 10),

                // Quantity
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    initialValue: item.quantity.toString(),
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 13),
                    decoration: _inputDecoration(hintText: 'Qty', icon: Icons.numbers_rounded, isDark: isDark),
                    onChanged: (v) {
                      setState(() {
                        item.quantity = int.tryParse(v) ?? 0;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 10),

                // Remove button
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 20),
                  tooltip: 'Remove Row',
                  onPressed: _items.length > 1
                      ? () {
                          setState(() => _items.removeAt(index));
                        }
                      : null,
                ),
              ],
            ),
          const SizedBox(height: 10),

          // Cost Breakdown Inputs (Base, Packaging, Freight, Handling)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: isCompact
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('1. Base Unit (₦)', style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w600, color: const Color(0xFF64748B))),
                                const SizedBox(height: 4),
                                TextFormField(
                                  initialValue: item.unitCost.toStringAsFixed(0),
                                  keyboardType: TextInputType.number,
                                  style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 12.5),
                                  decoration: _denseInputDecoration(isDark),
                                  onChanged: (v) => setState(() => item.unitCost = double.tryParse(v) ?? 0),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('2. Packaging / Unit (₦)', style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w600, color: const Color(0xFF64748B))),
                                const SizedBox(height: 4),
                                TextFormField(
                                  initialValue: item.packagingCost.toStringAsFixed(0),
                                  keyboardType: TextInputType.number,
                                  style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 12.5),
                                  decoration: _denseInputDecoration(isDark),
                                  onChanged: (v) => setState(() => item.packagingCost = double.tryParse(v) ?? 0),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('3. Freight / Unit (₦)', style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w600, color: const Color(0xFF64748B))),
                                const SizedBox(height: 4),
                                TextFormField(
                                  initialValue: item.freightCost.toStringAsFixed(0),
                                  keyboardType: TextInputType.number,
                                  style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 12.5),
                                  decoration: _denseInputDecoration(isDark),
                                  onChanged: (v) => setState(() => item.freightCost = double.tryParse(v) ?? 0),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('4. Handling / Unit (₦)', style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w600, color: const Color(0xFF64748B))),
                                const SizedBox(height: 4),
                                TextFormField(
                                  initialValue: item.handlingCost.toStringAsFixed(0),
                                  keyboardType: TextInputType.number,
                                  style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 12.5),
                                  decoration: _denseInputDecoration(isDark),
                                  onChanged: (v) => setState(() => item.handlingCost = double.tryParse(v) ?? 0),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D9488).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF0D9488).withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Landed: ₦${_currencyFormat.format(item.landedCostPerUnit)}/u',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF0D9488),
                              ),
                            ),
                            Text(
                              'Total: ₦${_currencyFormat.format(item.lineTotalLandedCost)}',
                              style: GoogleFonts.inter(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('1. Base Unit (₦)', style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w600, color: const Color(0xFF64748B))),
                            const SizedBox(height: 4),
                            TextFormField(
                              initialValue: item.unitCost.toStringAsFixed(0),
                              keyboardType: TextInputType.number,
                              style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 12.5),
                              decoration: _denseInputDecoration(isDark),
                              onChanged: (v) => setState(() => item.unitCost = double.tryParse(v) ?? 0),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('2. Packaging / Unit (₦)', style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w600, color: const Color(0xFF64748B))),
                            const SizedBox(height: 4),
                            TextFormField(
                              initialValue: item.packagingCost.toStringAsFixed(0),
                              keyboardType: TextInputType.number,
                              style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 12.5),
                              decoration: _denseInputDecoration(isDark),
                              onChanged: (v) => setState(() => item.packagingCost = double.tryParse(v) ?? 0),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('3. Freight / Unit (₦)', style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w600, color: const Color(0xFF64748B))),
                            const SizedBox(height: 4),
                            TextFormField(
                              initialValue: item.freightCost.toStringAsFixed(0),
                              keyboardType: TextInputType.number,
                              style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 12.5),
                              decoration: _denseInputDecoration(isDark),
                              onChanged: (v) => setState(() => item.freightCost = double.tryParse(v) ?? 0),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('4. Handling / Unit (₦)', style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w600, color: const Color(0xFF64748B))),
                            const SizedBox(height: 4),
                            TextFormField(
                              initialValue: item.handlingCost.toStringAsFixed(0),
                              keyboardType: TextInputType.number,
                              style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 12.5),
                              decoration: _denseInputDecoration(isDark),
                              onChanged: (v) => setState(() => item.handlingCost = double.tryParse(v) ?? 0),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Effective Landed Cost Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D9488).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF0D9488).withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Landed: ₦${_currencyFormat.format(item.landedCostPerUnit)}/u',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF0D9488),
                              ),
                            ),
                            Text(
                              'Total: ₦${_currencyFormat.format(item.lineTotalLandedCost)}',
                              style: GoogleFonts.inter(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryMetric(String title, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 11,
            color: const Color(0xFF99F6E4),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildLabel(String text, bool isDark) {
    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 12.5,
        fontWeight: FontWeight.w700,
        color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hintText,
    required IconData icon,
    required bool isDark,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94A3B8)),
      prefixIcon: Icon(icon, size: 18, color: const Color(0xFF0D9488)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      filled: true,
      fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF0D9488), width: 1.8),
      ),
    );
  }

  InputDecoration _denseInputDecoration(bool isDark) {
    return InputDecoration(
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      filled: true,
      fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: Color(0xFF0D9488), width: 1.5),
      ),
    );
  }
}
