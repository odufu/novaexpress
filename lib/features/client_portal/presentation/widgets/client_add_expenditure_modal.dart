import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:novexps/core/theme/theme_provider.dart';
import '../../domain/entities/business_expenditure.dart';
import '../../data/repositories/expenditure_repository.dart';
import '../providers/client_portal_provider.dart';

class ClientAddExpenditureModal extends ConsumerStatefulWidget {
  final String? clientId;
  final String? distributionCenterId;
  final String entityType; // 'merchant', 'grand_dc', 'sub_dc'
  final String? initialProductId;

  const ClientAddExpenditureModal({
    super.key,
    this.clientId,
    this.distributionCenterId,
    this.entityType = 'merchant',
    this.initialProductId,
  });

  static Future<BusinessExpenditureEntity?> show(
    BuildContext context, {
    String? clientId,
    String? distributionCenterId,
    String entityType = 'merchant',
    String? initialProductId,
  }) {
    return showDialog<BusinessExpenditureEntity>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ClientAddExpenditureModal(
        clientId: clientId,
        distributionCenterId: distributionCenterId,
        entityType: entityType,
        initialProductId: initialProductId,
      ),
    );
  }

  @override
  ConsumerState<ClientAddExpenditureModal> createState() => _ClientAddExpenditureModalState();
}

class _ClientAddExpenditureModalState extends ConsumerState<ClientAddExpenditureModal> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();

  late DateTime _selectedDate;
  ExpenditureCategory _selectedCategory = ExpenditureCategory.advertisement;
  String? _selectedProductId;

  // Attachment state
  String? _pickedFileName;
  String? _pickedFileExt;
  Uint8List? _pickedFileBytes;
  bool _isUploading = false;
  String? _uploadStatusText;

  final ExpenditureRepository _repo = ExpenditureRepository();

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _selectedProductId = widget.initialProductId;
    if (widget.entityType != 'merchant') {
      _selectedCategory = ExpenditureCategory.dieselFuel;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickAttachment() async {
    try {
      final result = await FilePickerPlatform.instance.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg', 'webp'],
      );

      if (result.isNotEmpty) {
        final file = result.first;
        final bytes = await file.readAsBytes();
        if (bytes.isNotEmpty) {
          setState(() {
            _pickedFileName = file.name;
            _pickedFileExt = file.extension?.toLowerCase() ?? 'pdf';
            _pickedFileBytes = bytes;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to select file: $e', style: GoogleFonts.inter(color: Colors.white)),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  Future<void> _selectDate() async {
    final themeMode = ref.read(themeProvider);
    final isDark = themeMode == ThemeMode.dark ||
        (themeMode == ThemeMode.system &&
            MediaQuery.of(context).platformBrightness == Brightness.dark);

    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: isDark
                ? const ColorScheme.dark(
                    primary: Color(0xFF10B981),
                    onPrimary: Colors.white,
                    surface: Color(0xFF1E293B),
                    onSurface: Colors.white,
                  )
                : const ColorScheme.light(
                    primary: Color(0xFF10B981),
                    onPrimary: Colors.white,
                    surface: Colors.white,
                    onSurface: Color(0xFF0F172A),
                  ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.tryParse(_amountController.text.replaceAll(',', '').trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter a valid amount greater than ₦0.', style: GoogleFonts.inter(color: Colors.white)),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadStatusText = 'Saving expenditure...';
    });

    try {
      String? receiptUrl;

      // 1. Upload receipt if attached
      if (_pickedFileBytes != null && _pickedFileName != null) {
        setState(() {
          _uploadStatusText = 'Uploading receipt/invoice proof...';
        });

        final targetId = widget.clientId ?? widget.distributionCenterId ?? 'general';
        final mimeType = _pickedFileExt == 'pdf'
            ? 'application/pdf'
            : (_pickedFileExt == 'png' ? 'image/png' : 'image/jpeg');

        receiptUrl = await _repo.uploadReceiptAttachment(
          fileBytes: _pickedFileBytes!,
          fileName: _pickedFileName!,
          mimeType: mimeType,
          entityId: targetId,
        );
      }

      // 2. Persist to database
      setState(() {
        _uploadStatusText = 'Recording to financial ledger...';
      });

      final exp = BusinessExpenditureEntity(
        id: '',
        clientId: widget.clientId,
        distributionCenterId: widget.distributionCenterId,
        entityType: widget.entityType,
        productId: _selectedProductId,
        category: _selectedCategory,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
        amount: amount,
        expenditureDate: _selectedDate,
        receiptUrl: receiptUrl,
        receiptFileName: _pickedFileName,
        createdAt: DateTime.now(),
      );

      final created = await _repo.createExpenditure(exp);

      if (!mounted) return;

      Navigator.of(context).pop(created);

      if (created != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981)),
                const SizedBox(width: 10),
                Text('Expenditure recorded successfully!', style: GoogleFonts.inter(color: Colors.white)),
              ],
            ),
            backgroundColor: const Color(0xFF0F172A),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error recording expenditure: $e', style: GoogleFonts.inter(color: Colors.white)),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final clientState = ref.watch(clientPortalProvider);
    final products = clientState.products;
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == ThemeMode.dark ||
        (themeMode == ThemeMode.system &&
            MediaQuery.of(context).platformBrightness == Brightness.dark);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: 600,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.08),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Modal Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF43F5E).withValues(alpha: isDark ? 0.15 : 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.receipt_long_rounded, color: Color(0xFFF43F5E), size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Record Business Expenditure',
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          'Track OpEx, Marketing, Procurement & Attach Invoices',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                    onPressed: _isUploading ? null : () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Form Body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Text(
                        'Expenditure Title / Reference',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _titleController,
                        style: GoogleFonts.inter(
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                          fontSize: 14,
                        ),
                        decoration: _inputDecoration('e.g., TikTok Influencer Campaign #04, Batch A Diesel', isDark),
                        validator: (val) => (val == null || val.trim().isEmpty) ? 'Title is required' : null,
                      ),
                      const SizedBox(height: 18),

                      // Amount & Date in 2 columns
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Amount (₦)',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _amountController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  style: GoogleFonts.outfit(
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  decoration: _inputDecoration('0.00', isDark, prefixText: '₦ '),
                                  validator: (val) {
                                    if (val == null || val.trim().isEmpty) return 'Amount required';
                                    if (double.tryParse(val.replaceAll(',', '')) == null) return 'Enter valid number';
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Date of Expense',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                InkWell(
                                  onTap: _selectDate,
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.calendar_today_rounded, size: 16, color: Color(0xFF10B981)),
                                        const SizedBox(width: 10),
                                        Text(
                                          DateFormat('dd MMM yyyy').format(_selectedDate),
                                          style: GoogleFonts.inter(
                                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Category Dropdown
                      Text(
                        'Expense Category',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<ExpenditureCategory>(
                        value: _selectedCategory,
                        dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                        style: GoogleFonts.inter(
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                          fontSize: 14,
                        ),
                        decoration: _inputDecoration('Select category', isDark),
                        items: ExpenditureCategory.values.map((cat) {
                          return DropdownMenuItem(
                            value: cat,
                            child: Row(
                              children: [
                                Icon(_getCategoryIcon(cat), size: 16, color: _getCategoryColor(cat)),
                                const SizedBox(width: 10),
                                Text(
                                  cat.label,
                                  style: GoogleFonts.inter(
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedCategory = val);
                        },
                      ),
                      const SizedBox(height: 18),

                      if (widget.entityType == 'merchant') ...[
                        // Optional Product Link (Hybrid Model)
                        Row(
                          children: [
                            Text(
                              'Associated Product (Optional)',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Tooltip(
                              message: 'Link this expense to a specific SKU to calculate direct Unit Economics, or leave as General Company Overhead.',
                              child: Icon(Icons.info_outline_rounded, size: 15, color: Colors.blueGrey.shade400),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String?>(
                          value: _selectedProductId,
                          dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                          style: GoogleFonts.inter(
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                            fontSize: 14,
                          ),
                          decoration: _inputDecoration('Link to product or general overhead', isDark),
                          items: [
                            DropdownMenuItem<String?>(
                              value: null,
                              child: Text(
                                '🏢 General Company Overhead (Not tied to single SKU)',
                                style: GoogleFonts.inter(
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                  fontSize: 13,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                            ...products.map((p) {
                              return DropdownMenuItem<String?>(
                                value: p.id,
                                child: Text(
                                  '📦 ${p.name} (${p.sku.isNotEmpty ? p.sku : 'SKU'})',
                                  style: GoogleFonts.inter(
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    fontSize: 13,
                                  ),
                                ),
                              );
                            }),
                          ],
                          onChanged: (val) => setState(() => _selectedProductId = val),
                        ),
                        const SizedBox(height: 18),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF38BDF8).withValues(alpha: isDark ? 0.1 : 0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.2)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.warehouse_rounded, size: 18, color: Color(0xFF38BDF8)),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Attributed directly to Distribution Hub Facility OpEx',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                      ],

                      // Description
                      Text(
                        'Additional Notes / Supplier Info',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _descriptionController,
                        maxLines: 2,
                        style: GoogleFonts.inter(
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                          fontSize: 13,
                        ),
                        decoration: _inputDecoration('Optional notes, vendor details, bank transfer ref...', isDark),
                      ),
                      const SizedBox(height: 20),

                      // Receipt & Invoice Attachment Section
                      Text(
                        'Invoice / Receipt Attachment (PDF or Image)',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.6) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                            style: BorderStyle.solid,
                          ),
                        ),
                        child: _pickedFileName == null
                            ? Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Attach proof of payment or vendor bill',
                                          style: GoogleFonts.inter(
                                            color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B),
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        Text(
                                          'Supported formats: PDF, PNG, JPG, WebP (Max 15MB)',
                                          style: GoogleFonts.inter(
                                            color: const Color(0xFF64748B),
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: _pickAttachment,
                                    icon: const Icon(Icons.attach_file_rounded, size: 16),
                                    label: Text('Browse File', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                                      side: BorderSide(color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7)),
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                  ),
                                ],
                              )
                            : Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: _pickedFileExt == 'pdf'
                                          ? const Color(0xFFEF4444).withValues(alpha: 0.2)
                                          : const Color(0xFF38BDF8).withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      _pickedFileExt == 'pdf'
                                          ? Icons.picture_as_pdf_rounded
                                          : Icons.image_rounded,
                                      color: _pickedFileExt == 'pdf'
                                          ? const Color(0xFFEF4444)
                                          : (isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7)),
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _pickedFileName!,
                                          style: GoogleFonts.inter(
                                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          '${((_pickedFileBytes?.length ?? 0) / 1024).toStringAsFixed(1)} KB • Ready to upload',
                                          style: GoogleFonts.inter(color: const Color(0xFF10B981), fontSize: 11),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFF43F5E), size: 20),
                                    onPressed: () => setState(() {
                                      _pickedFileName = null;
                                      _pickedFileExt = null;
                                      _pickedFileBytes = null;
                                    }),
                                  ),
                                ],
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Modal Action Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isUploading ? null : () => Navigator.of(context).pop(),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.inter(
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  ElevatedButton(
                    onPressed: _isUploading ? null : _handleSubmit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    child: _isUploading
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              ),
                              const SizedBox(width: 10),
                              Text(_uploadStatusText ?? 'Processing...', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
                            ],
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.check_rounded, size: 18),
                              const SizedBox(width: 8),
                              Text('Save Expenditure', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold)),
                            ],
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

  InputDecoration _inputDecoration(String hint, bool isDark, {String? prefixText}) {
    return InputDecoration(
      hintText: hint,
      prefixText: prefixText,
      prefixStyle: GoogleFonts.outfit(
        color: const Color(0xFF10B981),
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
      hintStyle: GoogleFonts.inter(
        color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
        fontSize: 13,
      ),
      filled: true,
      fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFEF4444)),
      ),
    );
  }

  IconData _getCategoryIcon(ExpenditureCategory cat) {
    switch (cat) {
      case ExpenditureCategory.advertisement:
        return Icons.campaign_rounded;
      case ExpenditureCategory.procurement:
        return Icons.inventory_2_rounded;
      case ExpenditureCategory.logistics:
        return Icons.local_shipping_rounded;
      case ExpenditureCategory.salaries:
        return Icons.people_alt_rounded;
      case ExpenditureCategory.rentUtilities:
        return Icons.apartment_rounded;
      case ExpenditureCategory.packaging:
        return Icons.all_inbox_rounded;
      case ExpenditureCategory.riderAllowance:
        return Icons.two_wheeler_rounded;
      case ExpenditureCategory.dieselFuel:
        return Icons.local_gas_station_rounded;
      case ExpenditureCategory.equipmentMaintenance:
        return Icons.build_rounded;
      case ExpenditureCategory.facilitySupplies:
        return Icons.cleaning_services_rounded;
      case ExpenditureCategory.stationery:
        return Icons.edit_note_rounded;
      case ExpenditureCategory.security:
        return Icons.security_rounded;
      case ExpenditureCategory.other:
        return Icons.more_horiz_rounded;
    }
  }

  Color _getCategoryColor(ExpenditureCategory cat) {
    switch (cat) {
      case ExpenditureCategory.advertisement:
        return const Color(0xFFF59E0B);
      case ExpenditureCategory.procurement:
        return const Color(0xFF3B82F6);
      case ExpenditureCategory.logistics:
        return const Color(0xFF8B5CF6);
      case ExpenditureCategory.salaries:
        return const Color(0xFF10B981);
      case ExpenditureCategory.rentUtilities:
        return const Color(0xFFEC4899);
      case ExpenditureCategory.packaging:
        return const Color(0xFF06B6D4);
      case ExpenditureCategory.riderAllowance:
        return const Color(0xFFF97316);
      case ExpenditureCategory.dieselFuel:
        return const Color(0xFFEF4444);
      case ExpenditureCategory.equipmentMaintenance:
        return const Color(0xFF64748B);
      case ExpenditureCategory.facilitySupplies:
        return const Color(0xFF14B8A6);
      case ExpenditureCategory.stationery:
        return const Color(0xFF6366F1);
      case ExpenditureCategory.security:
        return const Color(0xFF0284C7);
      case ExpenditureCategory.other:
        return const Color(0xFF94A3B8);
    }
  }
}
