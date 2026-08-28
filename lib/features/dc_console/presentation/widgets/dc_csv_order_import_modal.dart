import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/helpers/formatters.dart';
import '../../../orders/presentation/providers/orders_provider.dart';
import '../providers/dc_console_provider.dart';

class ParsedCsvOrderRow {
  final int rowNumber;
  final String orderNumber;
  final String customerName;
  final String customerPhone;
  final String? customerAltPhone;
  final String deliveryAddress;
  final String deliveryCity;
  final String deliveryState;
  final String productName;
  final int quantity;
  final double totalAmount;
  final String paymentType; // 'pay_on_delivery' or 'prepaid'
  final String clientName;
  final String? notes;
  final String? riderCode;
  final bool isValid;
  final String? validationError;

  ParsedCsvOrderRow({
    required this.rowNumber,
    required this.orderNumber,
    required this.customerName,
    required this.customerPhone,
    this.customerAltPhone,
    required this.deliveryAddress,
    required this.deliveryCity,
    required this.deliveryState,
    required this.productName,
    required this.quantity,
    required this.totalAmount,
    required this.paymentType,
    required this.clientName,
    this.notes,
    this.riderCode,
    required this.isValid,
    this.validationError,
  });

  Map<String, dynamic> toOrderPayload({
    String? overrideRiderId,
    String? overrideRiderName,
    String? overrideRiderCode,
  }) {
    final finalRiderId = overrideRiderId;
    final finalRiderName = overrideRiderName;
    final finalRiderCode = overrideRiderCode ?? riderCode;

    return {
      'order_number': orderNumber,
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'customer_alt_phone': customerAltPhone,
      'delivery_address': deliveryAddress,
      'delivery_city': deliveryCity,
      'delivery_state': deliveryState,
      'product_name': productName,
      'quantity': quantity,
      'paid_quantity': quantity,
      'free_quantity': 0,
      'base_price': quantity > 0 ? (totalAmount / quantity) : totalAmount,
      'upsell_amount': 0.0,
      'total_amount': totalAmount,
      'payment_type': paymentType,
      'payment_status': paymentType == 'prepaid' ? 'collected' : 'pending',
      'client_name': clientName,
      'delivery_notes': notes ?? 'CSV Bulk Import',
      'fulfillment_type': 'distributed_inventory',
      if (finalRiderId != null && finalRiderId.isNotEmpty) 'delivery_agent_id': finalRiderId,
      if (finalRiderName != null && finalRiderName.isNotEmpty) 'delivery_agent_name': finalRiderName,
      if (finalRiderCode != null && finalRiderCode.isNotEmpty) 'delivery_agent_code': finalRiderCode,
      if (finalRiderId != null && finalRiderId.isNotEmpty) 'status': 'in_transit' else 'status': 'assigned',
    };
  }
}

class DCCsvOrderImportModal extends ConsumerStatefulWidget {
  const DCCsvOrderImportModal({super.key});

  @override
  ConsumerState<DCCsvOrderImportModal> createState() => _DCCsvOrderImportModalState();
}

class _DCCsvOrderImportModalState extends ConsumerState<DCCsvOrderImportModal> {
  int _activeInputTab = 0; // 0: File Pick, 1: Paste Text
  final TextEditingController _csvTextController = TextEditingController();
  String? _selectedFileName;
  List<ParsedCsvOrderRow> _parsedRows = [];
  bool _isParsing = false;
  bool _isImporting = false;
  String? _parseError;

  // Optional bulk rider assignment
  String? _selectedBulkRiderId;
  String? _selectedBulkRiderName;
  String? _selectedBulkRiderCode;

  static const String sampleCsvTemplate = '''order_number,customer_name,customer_phone,delivery_address,delivery_city,delivery_state,product_name,quantity,total_amount,payment_type,client_name,notes
ORD-NOV-901,Alhaji Bello Hassan,08031122334,14 Aminu Kano Crescent,Wuse 2,FCT - Abuja,Respira Detox Tea,2,50000,pay_on_delivery,Novacare Limited,Call before arrival
ORD-NOV-902,Mrs. Blessing Okafor,08055667788,22 Gana Street,Maitama,FCT - Abuja,Grazer Weight Loss,1,20000,prepaid,Novacare Limited,Leave with security if absent
ORD-NOV-903,Engr. Tunde Bakare,08099887766,8 Adetokunbo Ademola,Wuse 2,FCT - Abuja,Respira Lungs Detox,1,25000,pay_on_delivery,HealthPlus Direct,Call at the gate''';

  @override
  void dispose() {
    _csvTextController.dispose();
    super.dispose();
  }

  Future<void> _pickCsvFile() async {
    try {
      setState(() {
        _isParsing = true;
        _parseError = null;
      });

      final result = await FilePickerPlatform.instance.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'txt'],
      );

      if (result.isNotEmpty) {
        final file = result.first;
        _selectedFileName = file.name;

        String rawContent = '';
        if (file.path != null) {
          final ioFile = File(file.path!);
          if (await ioFile.exists()) {
            rawContent = await ioFile.readAsString();
          }
        }

        if (rawContent.trim().isEmpty) {
          setState(() {
            _parseError = 'The selected file is empty or could not be read.';
            _isParsing = false;
          });
          return;
        }

        _parseCsvContent(rawContent);
      } else {
        setState(() {
          _isParsing = false;
        });
      }
    } catch (e) {
      setState(() {
        _parseError = 'Failed to read CSV file: $e';
        _isParsing = false;
      });
    }
  }

  static List<List<String>> _parseCsvRows(String input) {
    final List<List<String>> rows = [];
    final StringBuffer currentField = StringBuffer();
    List<String> currentRow = [];
    bool inQuotes = false;

    for (int i = 0; i < input.length; i++) {
      final char = input[i];

      if (char == '"') {
        if (inQuotes && i + 1 < input.length && input[i + 1] == '"') {
          currentField.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (char == ',' && !inQuotes) {
        currentRow.add(currentField.toString().trim());
        currentField.clear();
      } else if ((char == '\n' || char == '\r') && !inQuotes) {
        if (char == '\r' && i + 1 < input.length && input[i + 1] == '\n') {
          i++;
        }
        currentRow.add(currentField.toString().trim());
        currentField.clear();
        if (currentRow.any((field) => field.isNotEmpty)) {
          rows.add(currentRow);
        }
        currentRow = [];
      } else {
        currentField.write(char);
      }
    }

    if (currentField.isNotEmpty || currentRow.isNotEmpty) {
      currentRow.add(currentField.toString().trim());
      if (currentRow.any((field) => field.isNotEmpty)) {
        rows.add(currentRow);
      }
    }

    return rows;
  }

  void _parseCsvContent(String rawText) {
    try {
      setState(() {
        _isParsing = true;
        _parseError = null;
      });

      final cleanText = rawText.replaceAll('\r\n', '\n').replaceAll('\r', '\n').trim();
      if (cleanText.isEmpty) {
        setState(() {
          _parseError = 'No CSV data provided.';
          _parsedRows = [];
          _isParsing = false;
        });
        return;
      }

      final rows = _parseCsvRows(cleanText);

      if (rows.isEmpty || rows.length < 2) {
        setState(() {
          _parseError = 'CSV must contain a header row and at least one order row.';
          _parsedRows = [];
          _isParsing = false;
        });
        return;
      }

      // Map Headers to Column Indices
      final headerRow = rows.first.map((c) => c.toString().trim().toLowerCase().replaceAll(' ', '_').replaceAll('-', '_')).toList();

      int colIndex(List<String> synonyms) {
        for (final syn in synonyms) {
          final idx = headerRow.indexOf(syn);
          if (idx != -1) return idx;
        }
        return -1;
      }

      final idxOrderNo = colIndex(['order_number', 'order_no', 'order_id', 'tracking_number', 'tracking_id', 'id', 'ref']);
      final idxCustName = colIndex(['customer_name', 'customer', 'name', 'recipient', 'client_customer']);
      final idxPhone = colIndex(['customer_phone', 'phone', 'mobile', 'telephone', 'contact_phone', 'contact']);
      final idxAltPhone = colIndex(['customer_alt_phone', 'alt_phone', 'secondary_phone', 'other_phone']);
      final idxAddress = colIndex(['delivery_address', 'address', 'street_address', 'street', 'location', 'destination']);
      final idxCity = colIndex(['delivery_city', 'city', 'town', 'lga', 'district', 'area']);
      final idxState = colIndex(['delivery_state', 'state', 'region', 'province']);
      final idxProduct = colIndex(['product_name', 'product', 'item_name', 'item', 'goods', 'sku']);
      final idxQty = colIndex(['quantity', 'qty', 'units', 'count', 'number_of_items']);
      final idxAmount = colIndex(['total_amount', 'amount', 'price', 'total_price', 'value', 'order_amount', 'order_value']);
      final idxPaymentType = colIndex(['payment_type', 'payment_method', 'payment', 'type', 'pod_or_prepaid']);
      final idxClient = colIndex(['client_name', 'client', 'merchant', 'vendor', 'company_name', 'company']);
      final idxNotes = colIndex(['delivery_notes', 'notes', 'remarks', 'instructions', 'comment']);
      final idxRider = colIndex(['rider_code', 'rider_id', 'assigned_rider', 'agent_code', 'rider']);

      final List<ParsedCsvOrderRow> parsed = [];

      for (int i = 1; i < rows.length; i++) {
        final row = rows[i];
        if (row.isEmpty || (row.length == 1 && row.first.toString().trim().isEmpty)) continue;

        String getCol(int idx, [String fallback = '']) {
          if (idx >= 0 && idx < row.length) {
            final val = row[idx].trim();
            return val.isNotEmpty ? val : fallback;
          }
          return fallback;
        }

        final rawOrderNo = getCol(idxOrderNo);
        final rawCustName = getCol(idxCustName);
        final rawPhone = getCol(idxPhone);
        final rawAltPhone = getCol(idxAltPhone);
        final rawAddress = getCol(idxAddress);
        final rawCity = getCol(idxCity, 'Wuse 2');
        final rawState = getCol(idxState, 'FCT - Abuja');
        final rawProduct = getCol(idxProduct, 'Respira Detox Tea');
        final rawQtyStr = getCol(idxQty, '1');
        final rawAmountStr = getCol(idxAmount, '25000');
        final rawPaymentTypeStr = getCol(idxPaymentType, 'pay_on_delivery').toLowerCase();
        final rawClient = getCol(idxClient, 'Novacare Limited');
        final rawNotes = getCol(idxNotes);
        final rawRider = getCol(idxRider);

        final int qty = int.tryParse(rawQtyStr.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1;
        final double amount = double.tryParse(rawAmountStr.replaceAll(RegExp(r'[^0-9.]'), '')) ?? (qty * 25000.0);

        String normPaymentType = 'pay_on_delivery';
        if (rawPaymentTypeStr.contains('prepaid') || rawPaymentTypeStr.contains('transfer') || rawPaymentTypeStr.contains('paid') || rawPaymentTypeStr.contains('card')) {
          normPaymentType = 'prepaid';
        }

        final orderNumber = rawOrderNo.isNotEmpty ? rawOrderNo : 'ORD-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}-${i.toString().padLeft(2, '0')}';

        // Validation Checks
        String? error;
        if (rawCustName.isEmpty) {
          error = 'Missing customer name';
        } else if (rawPhone.isEmpty || rawPhone.length < 8) {
          error = 'Missing / invalid customer phone';
        } else if (rawAddress.isEmpty) {
          error = 'Missing delivery address';
        } else if (rawProduct.isEmpty) {
          error = 'Missing product name';
        } else if (amount <= 0) {
          error = 'Order total amount must be > ₦0';
        }

        parsed.add(ParsedCsvOrderRow(
          rowNumber: i,
          orderNumber: orderNumber,
          customerName: rawCustName.isNotEmpty ? rawCustName : 'Customer $i',
          customerPhone: rawPhone,
          customerAltPhone: rawAltPhone.isNotEmpty ? rawAltPhone : null,
          deliveryAddress: rawAddress,
          deliveryCity: rawCity,
          deliveryState: rawState,
          productName: rawProduct,
          quantity: qty > 0 ? qty : 1,
          totalAmount: amount,
          paymentType: normPaymentType,
          clientName: rawClient,
          notes: rawNotes.isNotEmpty ? rawNotes : null,
          riderCode: rawRider.isNotEmpty ? rawRider : null,
          isValid: error == null,
          validationError: error,
        ));
      }

      setState(() {
        _parsedRows = parsed;
        _isParsing = false;
        if (parsed.isEmpty) {
          _parseError = 'No valid rows found in CSV.';
        }
      });
    } catch (e) {
      setState(() {
        _parseError = 'Error parsing CSV structure: $e';
        _isParsing = false;
      });
    }
  }

  Future<void> _executeImport() async {
    final validRows = _parsedRows.where((r) => r.isValid).toList();
    if (validRows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No valid order rows to import. Please check errors.'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    setState(() {
      _isImporting = true;
    });

    final List<Map<String, dynamic>> payloads = validRows.map((r) {
      return r.toOrderPayload(
        overrideRiderId: _selectedBulkRiderId,
        overrideRiderName: _selectedBulkRiderName,
        overrideRiderCode: _selectedBulkRiderCode,
      );
    }).toList();

    final result = await ref.read(ordersProvider.notifier).bulkCreateOrders(payloads);

    if (!mounted) return;

    setState(() {
      _isImporting = false;
    });

    final int importedCount = result['importedCount'] ?? 0;
    final int failedCount = result['failedCount'] ?? 0;

    if (importedCount > 0) {
      // Reload DC orders
      ref.read(ordersProvider.notifier).loadDcOrders('22222222-2222-4222-8222-222222222222');

      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '🎉 Successfully imported $importedCount orders into Distribution Center!',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF16A34A),
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to import orders ($failedCount failed). Please try again.'),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    }
  }

  void _copyTemplateToClipboard() {
    Clipboard.setData(const ClipboardData(text: sampleCsvTemplate));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('📋 Sample CSV template copied to clipboard!'),
        backgroundColor: Color(0xFF2563EB),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final dcState = ref.watch(dcConsoleProvider);
    final fleetDrivers = dcState.drivers;

    final validCount = _parsedRows.where((r) => r.isValid).length;
    final invalidCount = _parsedRows.where((r) => !r.isValid).length;
    final double totalValuation = _parsedRows.where((r) => r.isValid).fold(0.0, (acc, r) => acc + r.totalAmount);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Container(
        width: 900,
        height: 720,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.6 : 0.15),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            // Modal Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.file_upload_rounded, color: Color(0xFF2563EB), size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            Text(
                              'Import Orders via CSV',
                              style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF37021).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'BATCH CREATION',
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFFF37021),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Upload spreadsheet data to instantly create multiple delivery manifests',
                          style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _copyTemplateToClipboard,
                    icon: const Icon(Icons.copy_rounded, size: 14, color: Color(0xFF2563EB)),
                    label: const Text('Sample Template', style: TextStyle(fontSize: 12, color: Color(0xFF2563EB), fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      side: const BorderSide(color: Color(0xFF93C5FD)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, size: 20),
                    style: IconButton.styleFrom(
                      backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    ),
                  ),
                ],
              ),
            ),

            // Modal Body
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Method Selector Tabs
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildMethodTab(0, 'Upload File (.csv)', Icons.upload_file_rounded, isDark),
                            const SizedBox(width: 10),
                            _buildMethodTab(1, 'Paste CSV Text', Icons.text_snippet_rounded, isDark),
                          ],
                        ),
                        if (_parsedRows.isNotEmpty)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Assign all to: ',
                                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF64748B)),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                height: 36,
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String?>(
                                    value: _selectedBulkRiderId,
                                    hint: Text('Unassigned Pool 📦', style: GoogleFonts.inter(fontSize: 12)),
                                    style: GoogleFonts.inter(fontSize: 12, color: isDark ? Colors.white : Colors.black87),
                                    dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                                    items: [
                                      DropdownMenuItem<String?>(
                                        value: null,
                                        child: Text('Unassigned Pool 📦', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                                      ),
                                      ...fleetDrivers.map((driver) {
                                        return DropdownMenuItem<String?>(
                                          value: driver.id,
                                          child: Text('🚴 ${driver.name} (${driver.driverCode})'),
                                        );
                                      }),
                                    ],
                                    onChanged: (val) {
                                      setState(() {
                                        _selectedBulkRiderId = val;
                                        if (val != null) {
                                          final d = fleetDrivers.firstWhere((dr) => dr.id == val);
                                          _selectedBulkRiderName = d.name;
                                          _selectedBulkRiderCode = d.driverCode;
                                        } else {
                                          _selectedBulkRiderName = null;
                                          _selectedBulkRiderCode = null;
                                        }
                                      });
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Input Panel (File Pick or Text Area)
                    if (_activeInputTab == 0) ...[
                      InkWell(
                        onTap: _isParsing ? null : _pickCsvFile,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                              style: BorderStyle.solid,
                              width: 1.5,
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.cloud_upload_outlined, size: 36, color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB)),
                              const SizedBox(height: 8),
                              Text(
                                _selectedFileName != null ? 'Selected: $_selectedFileName' : 'Click to choose a CSV file from your device',
                                style: GoogleFonts.inter(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Supports standard .csv format with headers (order_number, customer_name, phone, address, product, amount, etc.)',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ] else ...[
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: _csvTextController,
                            maxLines: 4,
                            style: GoogleFonts.jetBrainsMono(fontSize: 11.5),
                            decoration: InputDecoration(
                              hintText: 'Paste CSV rows here (e.g. order_number,customer_name,customer_phone,delivery_address,product_name,total_amount...)\n$sampleCsvTemplate',
                              hintStyle: GoogleFonts.jetBrainsMono(fontSize: 11, color: const Color(0xFF94A3B8)),
                              filled: true,
                              fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                              ),
                              contentPadding: const EdgeInsets.all(12),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              OutlinedButton.icon(
                                onPressed: () {
                                  _csvTextController.text = sampleCsvTemplate;
                                  _parseCsvContent(sampleCsvTemplate);
                                },
                                icon: const Icon(Icons.paste_rounded, size: 14),
                                label: const Text('Fill Sample CSV', style: TextStyle(fontSize: 11.5)),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                onPressed: () => _parseCsvContent(_csvTextController.text),
                                icon: const Icon(Icons.refresh_rounded, size: 14, color: Colors.white),
                                label: const Text('Parse Text', style: TextStyle(fontSize: 11.5, color: Colors.white, fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2563EB),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],

                    if (_parseError != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFEF4444)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _parseError!,
                                style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFFEF4444), fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 14),

                    // Metrics & Statistics Toolbar
                    if (_parsedRows.isNotEmpty) ...[
                      Row(
                        children: [
                          _buildStatCard('Total Rows', '${_parsedRows.length}', Icons.format_list_numbered_rounded, const Color(0xFF64748B), isDark),
                          const SizedBox(width: 8),
                          _buildStatCard('Valid Orders', '$validCount', Icons.check_circle_rounded, const Color(0xFF16A34A), isDark),
                          const SizedBox(width: 8),
                          _buildStatCard('Errors / Invalid', '$invalidCount', Icons.warning_amber_rounded, const Color(0xFFDC2626), isDark),
                          const SizedBox(width: 8),
                          _buildStatCard('Total Valuation', CurrencyFormatter.formatNaira(totalValuation), Icons.payments_rounded, const Color(0xFF2563EB), isDark),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Parsed Orders Table Header
                      Text(
                        'PREVIEW PARSED ORDERS (${_parsedRows.length})',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF64748B),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 6),

                      // Parsed Orders Table View
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.vertical,
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: DataTable(
                                  headingRowColor: WidgetStateProperty.all(isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
                                  columnSpacing: 18,
                                  dataRowMaxHeight: 48,
                                  columns: [
                                    const DataColumn(label: Text('#', style: TextStyle(fontWeight: FontWeight.bold))),
                                    const DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                                    const DataColumn(label: Text('Order Number', style: TextStyle(fontWeight: FontWeight.bold))),
                                    const DataColumn(label: Text('Customer & Phone', style: TextStyle(fontWeight: FontWeight.bold))),
                                    const DataColumn(label: Text('Destination', style: TextStyle(fontWeight: FontWeight.bold))),
                                    const DataColumn(label: Text('Product & Qty', style: TextStyle(fontWeight: FontWeight.bold))),
                                    const DataColumn(label: Text('Amount (₦)', style: TextStyle(fontWeight: FontWeight.bold))),
                                    const DataColumn(label: Text('Payment', style: TextStyle(fontWeight: FontWeight.bold))),
                                    const DataColumn(label: Text('Client', style: TextStyle(fontWeight: FontWeight.bold))),
                                  ],
                                  rows: _parsedRows.map((row) {
                                    return DataRow(
                                      color: WidgetStateProperty.resolveWith<Color?>((states) {
                                        if (!row.isValid) {
                                          return const Color(0xFFFEF2F2);
                                        }
                                        return null;
                                      }),
                                      cells: [
                                        DataCell(Text('${row.rowNumber}', style: GoogleFonts.jetBrainsMono(fontSize: 11.5))),
                                        DataCell(
                                          row.isValid
                                              ? Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFDCFCE7),
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: Text(
                                                    'VALID',
                                                    style: GoogleFonts.jetBrainsMono(fontSize: 9.5, fontWeight: FontWeight.bold, color: const Color(0xFF16A34A)),
                                                  ),
                                                )
                                              : Tooltip(
                                                  message: row.validationError ?? 'Invalid row',
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFFFEE2E2),
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    child: Text(
                                                      row.validationError ?? 'ERROR',
                                                      style: GoogleFonts.jetBrainsMono(fontSize: 9.5, fontWeight: FontWeight.bold, color: const Color(0xFFDC2626)),
                                                    ),
                                                  ),
                                                ),
                                        ),
                                        DataCell(Text(row.orderNumber, style: GoogleFonts.jetBrainsMono(fontSize: 11.5, fontWeight: FontWeight.bold))),
                                        DataCell(
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Text(row.customerName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                              Text(row.customerPhone, style: GoogleFonts.jetBrainsMono(fontSize: 10.5, color: const Color(0xFF64748B))),
                                            ],
                                          ),
                                        ),
                                        DataCell(
                                          Text(
                                            '${row.deliveryAddress}, ${row.deliveryCity}',
                                            style: const TextStyle(fontSize: 11.5),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        DataCell(Text('${row.productName} (x${row.quantity})', style: const TextStyle(fontSize: 11.5))),
                                        DataCell(Text(CurrencyFormatter.formatNaira(row.totalAmount), style: GoogleFonts.jetBrainsMono(fontSize: 11.5, fontWeight: FontWeight.bold))),
                                        DataCell(
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: row.paymentType == 'prepaid' ? const Color(0xFFE0E7FF) : const Color(0xFFFEF3C7),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              row.paymentType == 'prepaid' ? 'PREPAID' : 'POD CASH',
                                              style: GoogleFonts.jetBrainsMono(
                                                fontSize: 9.5,
                                                fontWeight: FontWeight.bold,
                                                color: row.paymentType == 'prepaid' ? const Color(0xFF4338CA) : const Color(0xFFB45309),
                                              ),
                                            ),
                                          ),
                                        ),
                                        DataCell(Text(row.clientName, style: const TextStyle(fontSize: 11.5))),
                                      ],
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ] else ...[
                      const Spacer(),
                      Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.table_chart_outlined, size: 48, color: const Color(0xFF94A3B8).withValues(alpha: 0.5)),
                            const SizedBox(height: 10),
                            Text(
                              'No CSV data loaded yet',
                              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Select a CSV file or paste spreadsheet text above to preview and import orders',
                              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                    ],
                  ],
                ),
              ),
            ),

            // Modal Footer Actions
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                border: Border(top: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _parsedRows = [];
                        _selectedFileName = null;
                        _csvTextController.clear();
                        _parseError = null;
                      });
                    },
                    icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFF64748B)),
                    label: const Text('Clear / Reset', style: TextStyle(color: Color(0xFF64748B))),
                  ),
                  Row(
                    children: [
                      OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: (_parsedRows.isEmpty || validCount == 0 || _isImporting) ? null : _executeImport,
                        icon: _isImporting
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.file_download_done_rounded, size: 18, color: Colors.white),
                        label: Text(
                          _isImporting ? 'Importing Orders...' : 'Confirm & Import $validCount Orders',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF16A34A),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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

  Widget _buildMethodTab(int tabIndex, String label, IconData icon, bool isDark) {
    final isSelected = _activeInputTab == tabIndex;
    return InkWell(
      onTap: () {
        setState(() {
          _activeInputTab = tabIndex;
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2563EB) : (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: isSelected ? Colors.white : const Color(0xFF64748B)),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF64748B), fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    value,
                    style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
