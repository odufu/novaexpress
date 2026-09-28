import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/nigeria_locations.dart';
import '../../../../core/helpers/formatters.dart';
import '../../domain/entities/lead_form.dart';
import '../providers/client_portal_provider.dart';

class PublicLeadFormPage extends ConsumerStatefulWidget {
  final String formId;

  const PublicLeadFormPage({super.key, required this.formId});

  @override
  ConsumerState<PublicLeadFormPage> createState() => _PublicLeadFormPageState();
}

class _PublicLeadFormPageState extends ConsumerState<PublicLeadFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _altPhoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _honeypotController = TextEditingController(); // Bot honeypot

  String _selectedState = 'Lagos';
  String _selectedLga = 'Ikeja';
  Map<String, dynamic>? _selectedPackage;
  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _isSubmitted = false;
  String? _errorMessage;
  LeadForm? _leadForm;
  Map<String, dynamic>? _submissionResult;

  @override
  void initState() {
    super.initState();
    _fetchLeadForm();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _altPhoneController.dispose();
    _addressController.dispose();
    _honeypotController.dispose();
    super.dispose();
  }

  Future<void> _fetchLeadForm() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final forms = ref.read(clientPortalProvider).leadForms;
      LeadForm? match = forms.where((f) => f.id == widget.formId || f.formSlug == widget.formId).firstOrNull;

      if (match == null) {
        // Fetch forms from remote repository
        await ref.read(clientPortalProvider.notifier).loadClientData();
        final updatedForms = ref.read(clientPortalProvider).leadForms;
        match = updatedForms.where((f) => f.id == widget.formId || f.formSlug == widget.formId).firstOrNull;
      }

      if (match != null) {
        setState(() {
          _leadForm = match;
          _isLoading = false;
          if (match!.packages.isNotEmpty) {
            final defaultPkg = match.packages.firstWhere(
              (p) => p['is_default'] == true,
              orElse: () => match!.packages.first,
            );
            _selectedPackage = defaultPkg;
          }
        });
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Form not found or has been archived.';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load form: $e';
      });
    }
  }

  Future<void> _submitOrder() async {
    // Bot honeypot check: real users never see or fill this field
    if (_honeypotController.text.trim().isNotEmpty) {
      setState(() => _isSubmitted = true);
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    if (_selectedPackage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an offer package')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final uri = Uri.base;
      final utmSource = uri.queryParameters['utm_source'] ?? 'direct';
      final utmMedium = uri.queryParameters['utm_medium'] ?? 'landing';
      final utmCampaign = uri.queryParameters['utm_campaign'];
      final utmContent = uri.queryParameters['utm_content'];
      final adId = uri.queryParameters['ad_id'];

      final pkgName = _selectedPackage!['name']?.toString() ?? 'Standard Package';
      final pkgPrice = (_selectedPackage!['price'] as num?)?.toDouble() ?? 25000.0;
      final pkgQty = (_selectedPackage!['quantity'] as num?)?.toInt() ?? 1;
      final paidQty = (_selectedPackage!['paid_quantity'] as num?)?.toInt() ?? pkgQty;
      final freeQty = (_selectedPackage!['free_quantity'] as num?)?.toInt() ?? 0;
      final pkgId = _selectedPackage!['id']?.toString();
      final actualPrice = (_selectedPackage!['actual_price'] as num?)?.toDouble();

      final rawPhone = _phoneController.text.trim();
      final normalizedPhone = NigerianPhoneHelper.normalize(rawPhone);
      final rawAltPhone = _altPhoneController.text.trim();
      final normalizedAltPhone = rawAltPhone.isNotEmpty ? NigerianPhoneHelper.normalize(rawAltPhone) : null;

      final result = await ref.read(clientPortalProvider.notifier).submitMarketingLeadOrder({
        'form_id': _leadForm!.id,
        'customer_name': _nameController.text.trim(),
        'customer_phone': normalizedPhone.isNotEmpty ? normalizedPhone : rawPhone,
        'delivery_address': _addressController.text.trim(),
        'delivery_state': _selectedState,
        'delivery_lga': _selectedLga.isNotEmpty ? _selectedLga : NigeriaLocations.getCitiesForState(_selectedState).first,
        'delivery_city': _selectedLga.isNotEmpty ? _selectedLga : NigeriaLocations.getCitiesForState(_selectedState).first,
        'package_selected': pkgName,
        'package_quantity': pkgQty,
        'order_amount': pkgPrice,
        'paid_quantity': paidQty,
        'free_quantity': freeQty,
        if (pkgId != null) 'package_deal_id': pkgId,
        if (actualPrice != null) 'actual_price': actualPrice,
        'utm_source': utmSource,
        'utm_medium': utmMedium,
        if (utmCampaign != null) 'utm_campaign': utmCampaign,
        if (utmContent != null) 'utm_content': utmContent,
        if (adId != null) 'ad_id': adId,
        'metadata': {
          if (normalizedAltPhone != null) 'alt_phone': normalizedAltPhone,
          'raw_phone_submitted': rawPhone,
          if (freeQty > 0) 'free_bonus_units': freeQty,
          if (actualPrice != null) 'retail_price': actualPrice,
        },
      });

      setState(() {
        _isSubmitted = true;
        _isSubmitting = false;
        _submissionResult = result;
      });

      // Handle Thank You Page Redirect (only for fresh orders)
      final isDuplicate = result['is_duplicate'] == true;
      if (!isDuplicate) {
        final redirectUrl = result['redirect_url']?.toString();
        if (redirectUrl != null && redirectUrl.isNotEmpty && redirectUrl.startsWith('http')) {
          Future.delayed(const Duration(milliseconds: 1500), () async {
            final targetUri = Uri.parse(redirectUrl);
            if (await canLaunchUrl(targetUri)) {
              await launchUrl(targetUri, mode: LaunchMode.platformDefault);
            }
          });
        }
      }
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: const Color(0xFFEF4444), content: Text('Error booking order: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(symbol: '₦', decimalDigits: 0);

    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8FAFC),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF10B981)),
        ),
      );
    }

    if (_errorMessage != null || _leadForm == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 48),
                const SizedBox(height: 12),
                Text(
                  _errorMessage ?? 'Form Not Found',
                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    final form = _leadForm!;

    if (_isSubmitted) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, 4)),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _submissionResult?['is_duplicate'] == true
                            ? const Color(0xFFF59E0B).withValues(alpha: 0.14)
                            : const Color(0xFF10B981).withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _submissionResult?['is_duplicate'] == true
                            ? Icons.verified_outlined
                            : Icons.check_circle_rounded,
                        color: _submissionResult?['is_duplicate'] == true
                            ? const Color(0xFFD97706)
                            : const Color(0xFF10B981),
                        size: 48,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _submissionResult?['is_duplicate'] == true
                          ? 'Order Already On File!'
                          : 'Order Successfully Received!',
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _submissionResult?['is_duplicate'] == true
                          ? 'Hello ${_nameController.text.trim()}, we already have an active order for this phone number currently queued for delivery.'
                          : 'Thank you, ${_nameController.text.trim()}. Your order for ${form.productName} has been booked.',
                      style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B)),
                      textAlign: TextAlign.center,
                    ),
                    if (_submissionResult?['order_number'] != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: _submissionResult?['is_duplicate'] == true
                              ? const Color(0xFFF59E0B).withValues(alpha: 0.12)
                              : const Color(0xFF10B981).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _submissionResult?['is_duplicate'] == true
                                ? const Color(0xFFF59E0B).withValues(alpha: 0.3)
                                : Colors.transparent,
                          ),
                        ),
                        child: Text(
                          'Order Ref: #${_submissionResult!["order_number"]}',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _submissionResult?['is_duplicate'] == true
                                ? const Color(0xFFB45309)
                                : const Color(0xFF10B981),
                          ),
                        ),
                      ),
                    ],
                    if (_submissionResult?['is_duplicate'] == true) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.shield_outlined, size: 18, color: Color(0xFFD97706)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'To protect you from duplicate charges and multiple deliveries, existing active orders are not duplicated. Our customer service agent will contact you shortly.',
                                style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF92400E), height: 1.4),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Selected Package', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
                              Text(_selectedPackage?['name']?.toString() ?? '', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700)),
                            ],
                          ),
                          if ((_selectedPackage?['free_quantity'] as num? ?? 0) > 0) ...[
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Deal Details', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF059669), fontWeight: FontWeight.w600)),
                                Text(
                                  '${_selectedPackage?['paid_quantity'] ?? _selectedPackage?['quantity']} Paid + ${_selectedPackage?['free_quantity']} FREE (${_selectedPackage?['quantity']} Total)',
                                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF059669)),
                                ),
                              ],
                            ),
                          ],
                          const Divider(height: 14),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Payment Mode', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
                              Text('Pay On Delivery', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF10B981))),
                            ],
                          ),
                          const Divider(height: 14),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Total Amount Due', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
                              Text(
                                currencyFormatter.format((_selectedPackage?['price'] as num?)?.toDouble() ?? 0.0),
                                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: const Color(0xFF10B981)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Icon(Icons.phone_in_talk_rounded, size: 16, color: Color(0xFF6366F1)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Our customer service agent will call ${_phoneController.text.trim()} shortly to confirm delivery.',
                            style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF6366F1), fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 580),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 24,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Form Header
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF10B981), Color(0xFF059669)],
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'PAY ON DELIVERY NATIONWIDE',
                                  style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white),
                                ),
                              ),
                              const Spacer(),
                              const Icon(Icons.verified_user_rounded, color: Colors.white, size: 16),
                              const SizedBox(width: 4),
                              Text('100% Genuine', style: GoogleFonts.inter(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600)),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            form.title,
                            style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Please fill the form below accurately to receive your package.',
                            style: GoogleFonts.inter(fontSize: 12, color: Colors.white.withValues(alpha: 0.9)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Section 1: Choose Package
                    Text(
                      'STEP 1: SELECT YOUR PREFERRED DEAL',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: const Color(0xFF10B981), letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 8),

                    ...form.packages.map((pkg) {
                      final isSelected = _selectedPackage?['id'] == pkg['id'];
                      final price = (pkg['price'] as num?)?.toDouble() ?? 0.0;
                      final actualPrice = (pkg['actual_price'] as num?)?.toDouble();
                      final badge = pkg['badge']?.toString() ?? '';
                      final paidQty = (pkg['paid_quantity'] as num?)?.toInt() ?? (pkg['quantity'] as num?)?.toInt() ?? 1;
                      final freeQty = (pkg['free_quantity'] as num?)?.toInt() ?? 0;
                      final totalUnits = (pkg['quantity'] as num?)?.toInt() ?? (paidQty + freeQty);
                      final hasDiscount = actualPrice != null && actualPrice > price;
                      final discountPercent = hasDiscount ? (((actualPrice - price) / actualPrice) * 100).round() : 0;

                      return GestureDetector(
                        onTap: () => setState(() => _selectedPackage = pkg),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFF10B981).withValues(alpha: 0.06) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Radio<String>(
                                value: pkg['id']?.toString() ?? '',
                                groupValue: _selectedPackage?['id']?.toString(),
                                activeColor: const Color(0xFF10B981),
                                onChanged: (_) => setState(() => _selectedPackage = pkg),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Wrap(
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      spacing: 6,
                                      runSpacing: 4,
                                      children: [
                                        Text(
                                          pkg['name']?.toString() ?? 'Deal',
                                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                                        ),
                                        if (badge.isNotEmpty)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFEF4444),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              badge,
                                              style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white),
                                            ),
                                          ),
                                        if (freeQty > 0)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF10B981),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              '🎁 +$freeQty FREE Bonus',
                                              style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    if (freeQty > 0)
                                      Text(
                                        '$paidQty Paid + $freeQty FREE Bonus = $totalUnits Total Units',
                                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF059669)),
                                      )
                                    else
                                      Text(
                                        'Quantity: $totalUnits unit(s)',
                                        style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (hasDiscount) ...[
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          currencyFormatter.format(actualPrice),
                                          style: GoogleFonts.inter(
                                            fontSize: 11,
                                            color: const Color(0xFF94A3B8),
                                            decoration: TextDecoration.lineThrough,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFDC2626).withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            '-$discountPercent%',
                                            style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w800, color: const Color(0xFFDC2626)),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                  ],
                                  Text(
                                    currencyFormatter.format(price),
                                    style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: const Color(0xFF10B981)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 16),

                    // Section 2: Delivery Details
                    Text(
                      'STEP 2: YOUR DELIVERY INFORMATION',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: const Color(0xFF10B981), letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 10),

                    // Full Name
                    Text('Full Name *', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF334155))),
                    const SizedBox(height: 5),
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        hintText: 'e.g. Joy Okafor',
                        prefixIcon: const Icon(Icons.person_outline_rounded, size: 20, color: Color(0xFF94A3B8)),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter your full name' : null,
                    ),
                    const SizedBox(height: 12),

                    // Phone Numbers
                    Text('Active WhatsApp / Phone Number *', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF334155))),
                    const SizedBox(height: 5),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        hintText: '08012345678',
                        prefixIcon: const Icon(Icons.phone_outlined, size: 20, color: Color(0xFF94A3B8)),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Please enter your phone number';
                        final clean = v.replaceAll(RegExp(r'\D'), '');
                        if (clean.length < 10) return 'Please enter a valid phone number';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),

                    Text('Alternative Phone Number (Optional)', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF334155))),
                    const SizedBox(height: 5),
                    TextFormField(
                      controller: _altPhoneController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        hintText: 'e.g. 09087654321',
                        prefixIcon: const Icon(Icons.phone_enabled_outlined, size: 20, color: Color(0xFF94A3B8)),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // State & LGA Cascade Selection
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isNarrow = constraints.maxWidth < 450;
                        final lgas = NigeriaLocations.getCitiesForState(_selectedState);
                        final currentLgaValue = lgas.contains(_selectedLga)
                            ? _selectedLga
                            : (lgas.isNotEmpty ? lgas.first : null);

                        final stateField = Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Delivery State *', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF334155))),
                            const SizedBox(height: 5),
                            DropdownButtonFormField<String>(
                              value: NigeriaLocations.states.contains(_selectedState) ? _selectedState : NigeriaLocations.states.first,
                              isExpanded: true,
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
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
                        );

                        final lgaField = Column(
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
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
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
                        );

                        if (isNarrow) {
                          return Column(
                            children: [
                              stateField,
                              const SizedBox(height: 12),
                              lgaField,
                            ],
                          );
                        } else {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: stateField),
                              const SizedBox(width: 12),
                              Expanded(child: lgaField),
                            ],
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 12),

                    // Street Address
                    Text('Exact Delivery Address (House No, Street, Landmark) *', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF334155))),
                    const SizedBox(height: 5),
                    TextFormField(
                      controller: _addressController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: 'e.g. No 15, Admiralty Way, beside Zenith Bank, Lekki Phase 1',
                        prefixIcon: const Padding(padding: EdgeInsets.only(bottom: 24), child: Icon(Icons.location_on_outlined, size: 20, color: Color(0xFF94A3B8))),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      ),
                      validator: (v) => (v == null || v.trim().length < 5) ? 'Please enter a complete delivery address' : null,
                    ),

                    // Invisible Bot Honeypot Input
                    Visibility(
                      visible: false,
                      child: TextFormField(
                        controller: _honeypotController,
                        decoration: const InputDecoration(labelText: 'Website'),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Trust Badges
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.lock_rounded, size: 14, color: Color(0xFF10B981)),
                              const SizedBox(width: 4),
                              Text('No Advance Payment', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF334155))),
                            ],
                          ),
                          Row(
                            children: [
                              const Icon(Icons.flash_on_rounded, size: 14, color: Color(0xFFF59E0B)),
                              const SizedBox(width: 4),
                              Text('Fast Dispatch', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF334155))),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Submit CTA Button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submitOrder,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 2,
                        ),
                        child: _isSubmitting
                            ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                            : Text(
                                form.buttonText.isNotEmpty ? form.buttonText : 'CLAIM YOUR ORDER (PAY ON DELIVERY)',
                                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.3),
                                textAlign: TextAlign.center,
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
