import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/nigeria_locations.dart';
import '../../../../core/constants/supabase_constants.dart';
import '../../../../core/widgets/client_logo_widget.dart';
import '../../../client_portal/domain/entities/client_profile.dart';
import '../providers/dc_console_provider.dart';

class DCEditClientModal extends ConsumerStatefulWidget {
  final ClientProfile client;

  const DCEditClientModal({
    super.key,
    required this.client,
  });

  static Future<ClientProfile?> show(BuildContext context, ClientProfile client) {
    return showDialog<ClientProfile>(
      context: context,
      barrierDismissible: false,
      builder: (_) => DCEditClientModal(client: client),
    );
  }

  @override
  ConsumerState<DCEditClientModal> createState() => _DCEditClientModalState();
}

class _DCEditClientModalState extends ConsumerState<DCEditClientModal>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late TabController _tabController;

  // Controllers - Profile
  late final TextEditingController _companyNameController;
  late final TextEditingController _contactPersonController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;
  late final TextEditingController _cityController;
  late final TextEditingController _closerLimitController;

  // State & Services
  late String _selectedState;
  late String _tier;
  late bool _hasInventoryManagement;
  late List<String> _servicesEnabled;
  late List<String> _operatingStates;

  // Brand Theming
  late final TextEditingController _logoUrlController;
  late final TextEditingController _primaryColorController;
  late final TextEditingController _secondaryColorController;
  late final TextEditingController _accentColorController;

  // Tariffs & Financials
  late final TextEditingController _deliveryFeeController;
  late final TextEditingController _failedFeeController;
  late final TextEditingController _platformFeeController;
  late final TextEditingController _bankNameController;
  late final TextEditingController _accountNumberController;
  late final TextEditingController _accountNameController;
  late String _settlementFrequency;
  late String _settlementDay;

  // Account Settings
  late bool _isActive;
  bool _isResettingPassword = false;
  bool _isUpdatingPassword = false;
  bool _isUploadingLogo = false;
  final TextEditingController _adminNewPasswordController = TextEditingController();
  final TextEditingController _adminConfirmPasswordController = TextEditingController();
  bool _obscureAdminPassword = true;

  bool _isSaving = false;

  static const List<Map<String, dynamic>> _brandPresets = [
    {
      'name': 'Novacare Emerald',
      'primary': '#0D9488',
      'secondary': '#031632',
      'accent': '#10B981',
      'color': Color(0xFF0D9488),
    },
    {
      'name': 'NovaXpress Blaze',
      'primary': '#F37021',
      'secondary': '#031632',
      'accent': '#3B82F6',
      'color': Color(0xFFF37021),
    },
    {
      'name': 'Royal Sapphire',
      'primary': '#2563EB',
      'secondary': '#0F172A',
      'accent': '#38BDF8',
      'color': Color(0xFF2563EB),
    },
    {
      'name': 'Imperial Violet',
      'primary': '#7C3AED',
      'secondary': '#1E1B4B',
      'accent': '#C084FC',
      'color': Color(0xFF7C3AED),
    },
    {
      'name': 'Crimson Ruby',
      'primary': '#DC2626',
      'secondary': '#450A0A',
      'accent': '#F87171',
      'color': Color(0xFFDC2626),
    },
    {
      'name': 'Corporate Slate',
      'primary': '#334155',
      'secondary': '#0F172A',
      'accent': '#64748B',
      'color': Color(0xFF334155),
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    final c = widget.client;

    _companyNameController = TextEditingController(text: c.companyName);
    _contactPersonController = TextEditingController(text: c.contactPerson);
    _emailController = TextEditingController(text: c.email);
    _phoneController = TextEditingController(text: c.phone);
    _addressController = TextEditingController(text: c.address);
    _cityController = TextEditingController(text: c.city.isNotEmpty ? c.city : 'Abuja');
    _closerLimitController = TextEditingController(text: c.closerLimit.toString());

    // Resiliently normalize state to NigeriaLocations.states
    final cState = c.state.trim().toLowerCase();
    _selectedState = NigeriaLocations.states.firstWhere(
      (s) {
        final stLow = s.toLowerCase();
        if (stLow == cState) return true;
        if (cState.contains('abuja') || cState.contains('fct') || cState.contains('federal')) {
          return stLow.contains('fct') || stLow.contains('abuja');
        }
        return stLow.contains(cState) || cState.contains(stLow);
      },
      orElse: () => 'FCT - Abuja',
    );

    // Resiliently normalize tier
    final cTier = c.tier.trim().toLowerCase();
    _tier = (cTier.contains('ent') || c.isEnterprise) ? 'enterprise' : 'standard_merchant';

    _hasInventoryManagement = c.hasInventoryManagement;
    _servicesEnabled = List.from(c.servicesEnabled);
    _operatingStates = List.from(c.operatingStates);

    _logoUrlController = TextEditingController(text: c.logoUrl ?? '');
    _primaryColorController = TextEditingController(text: c.primaryColor ?? '#0D9488');
    _secondaryColorController = TextEditingController(text: c.secondaryColor ?? '#031632');
    _accentColorController = TextEditingController(text: c.accentColor ?? '#10B981');

    _deliveryFeeController = TextEditingController(text: (c.customDeliveryFee ?? 5000.0).toStringAsFixed(0));
    _failedFeeController = TextEditingController(text: (c.customFailedAttemptFee ?? 1000.0).toStringAsFixed(0));
    _platformFeeController = TextEditingController(text: (c.customPlatformFeeValue ?? 500.0).toStringAsFixed(0));
    _bankNameController = TextEditingController(text: c.bankName.isNotEmpty ? c.bankName : 'Access Bank');
    _accountNumberController = TextEditingController(text: c.accountNumber);
    _accountNameController = TextEditingController(text: c.accountName.isNotEmpty ? c.accountName : c.companyName);

    // Resiliently normalize settlement frequency
    final cFreq = c.settlementFrequency.trim().toLowerCase();
    _settlementFrequency = (cFreq == 'daily' || cFreq == 'biweekly') ? cFreq : 'weekly';

    // Resiliently normalize settlement day
    final cDay = c.settlementDay.trim().toLowerCase();
    _settlementDay = (cDay.contains('every') || cDay == 'daily')
        ? 'Everyday'
        : (cDay.contains('mon') ? 'Monday' : 'Friday');

    _isActive = c.isActive;
  }

  @override
  void dispose() {
    _tabController.dispose();
    _companyNameController.dispose();
    _contactPersonController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _closerLimitController.dispose();
    _logoUrlController.dispose();
    _primaryColorController.dispose();
    _secondaryColorController.dispose();
    _accentColorController.dispose();
    _deliveryFeeController.dispose();
    _failedFeeController.dispose();
    _platformFeeController.dispose();
    _bankNameController.dispose();
    _accountNumberController.dispose();
    _accountNameController.dispose();
    _adminNewPasswordController.dispose();
    _adminConfirmPasswordController.dispose();
    super.dispose();
  }

  Color _parseHex(String hex, Color fallback) {
    try {
      final clean = hex.replaceAll('#', '').trim();
      if (clean.length == 6) {
        return Color(int.parse('0xFF$clean'));
      }
      return fallback;
    } catch (_) {
      return fallback;
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final deliveryFee = double.tryParse(_deliveryFeeController.text.trim()) ?? 5000.0;
      final failedFee = double.tryParse(_failedFeeController.text.trim()) ?? 1000.0;
      final platformFee = double.tryParse(_platformFeeController.text.trim()) ?? 500.0;
      final closerLimit = int.tryParse(_closerLimitController.text.trim()) ?? 0;

      final updated = await ref.read(dcConsoleProvider.notifier).updateClientFullProfileAndTariffs(
        clientId: widget.client.id,
        companyName: _companyNameController.text.trim(),
        contactPerson: _contactPersonController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        address: _addressController.text.trim(),
        city: _cityController.text.trim(),
        stateName: _selectedState,
        tier: _tier,
        closerLimit: closerLimit,
        hasInventoryManagement: _hasInventoryManagement,
        servicesEnabled: _servicesEnabled,
        operatingStates: _operatingStates,
        logoUrl: _logoUrlController.text.trim().isNotEmpty ? _logoUrlController.text.trim() : null,
        primaryColor: _primaryColorController.text.trim(),
        secondaryColor: _secondaryColorController.text.trim(),
        accentColor: _accentColorController.text.trim(),
        customDeliveryFee: deliveryFee,
        customFailedAttemptFee: failedFee,
        customPlatformFee: platformFee,
        bankName: _bankNameController.text.trim(),
        bankAccountNumber: _accountNumberController.text.trim(),
        bankAccountName: _accountNameController.text.trim(),
        settlementFrequency: _settlementFrequency,
        settlementDay: _settlementDay,
        isActive: _isActive,
      );

      if (!mounted) return;
      Navigator.of(context).pop(updated);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF10B981),
          content: Text('Client ${updated.companyName} profile & agreements updated successfully!'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFEF4444),
          content: Text('Update error: $e'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryPreview = _parseHex(_primaryColorController.text, const Color(0xFF0D9488));

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: double.infinity,
        constraints: BoxConstraints(
          maxWidth: 900,
          maxHeight: MediaQuery.of(context).size.height * 0.92,
        ),
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: primaryPreview.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.tune_rounded, color: primaryPreview, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                'Manage Merchant: ${widget.client.companyName}',
                                style: GoogleFonts.inter(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF64748B).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                widget.client.code,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                                ),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'Configure corporate profile, service tiers, brand theming, operating states and tariffs',
                          style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Tab Bar
              TabBar(
                controller: _tabController,
                isScrollable: MediaQuery.of(context).size.width < 560,
                tabAlignment: MediaQuery.of(context).size.width < 560 ? TabAlignment.start : TabAlignment.fill,
                labelColor: const Color(0xFF0D9488),
                unselectedLabelColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                indicatorColor: const Color(0xFF0D9488),
                indicatorWeight: 3,
                labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
                tabs: const [
                  Tab(text: 'Profile & Depots'),
                  Tab(text: 'Service Modules'),
                  Tab(text: 'Brand & Theming'),
                  Tab(text: 'Tariffs & Banking'),
                  Tab(text: 'Account Settings'),
                ],
              ),
              const Divider(height: 1),
              const SizedBox(height: 12),

              // Tab Views
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildProfileTab(isDark),
                    _buildServicesTab(isDark),
                    _buildBrandTab(isDark),
                    _buildTariffsTab(isDark),
                    _buildAccountSettingsTab(isDark),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Footer Actions
              Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text('Cancel', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                  ),
                  ElevatedButton.icon(
                    onPressed: _isSaving ? null : _handleSave,
                    icon: _isSaving
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.check_rounded, size: 18),
                    label: Text(
                      _isSaving ? 'Saving Changes...' : 'Save Merchant Profile',
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
            ],
          ),
        ),
      ),
    );
  }

  // --- Tab 1: Profile & Depots ---
  Widget _buildProfileTab(bool isDark) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        _buildResponsivePair(
          context,
          _buildTextField(
            label: 'Registered Company Name *',
            controller: _companyNameController,
            hint: 'e.g. Novacare Health & Wellness Ltd',
            isDark: isDark,
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
          _buildTextField(
            label: 'Managing Contact Person *',
            controller: _contactPersonController,
            hint: 'Dr. Chuke Okafor',
            isDark: isDark,
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
          flex1: 3,
          flex2: 2,
        ),
        const SizedBox(height: 14),
        _buildResponsivePair(
          context,
          _buildTextField(
            label: 'Official Corporate Email *',
            controller: _emailController,
            hint: 'operations@client.com',
            isDark: isDark,
            validator: (v) => (v == null || !v.contains('@')) ? 'Valid email required' : null,
          ),
          _buildTextField(
            label: 'Direct Phone / WhatsApp *',
            controller: _phoneController,
            hint: '+234 802 345 6789',
            isDark: isDark,
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
        ),
        const SizedBox(height: 14),
        _buildTextField(
          label: 'Physical Headquarter Address',
          controller: _addressController,
          hint: 'Plot 402 Aminu Kano Crescent, Wuse 2, Abuja',
          isDark: isDark,
        ),
        const SizedBox(height: 14),
        _buildResponsivePair(
          context,
          _buildTextField(
            label: 'City',
            controller: _cityController,
            hint: 'Abuja',
            isDark: isDark,
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Primary Hub State', style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              DropdownButtonFormField<String>(
                value: NigeriaLocations.states.contains(_selectedState) ? _selectedState : NigeriaLocations.states.first,
                items: NigeriaLocations.states.map((s) => DropdownMenuItem(value: s, child: Text(s, style: GoogleFonts.inter(fontSize: 13)))).toList(),
                onChanged: (v) => setState(() => _selectedState = v ?? _selectedState),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Operating Covering States
        Text(
          'Covered Distribution States (${_operatingStates.length} Active)',
          style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: NigeriaLocations.states.map((st) {
            final isSelected = _operatingStates.contains(st);
            return FilterChip(
              label: Text(st, style: GoogleFonts.inter(fontSize: 11)),
              selected: isSelected,
              selectedColor: const Color(0xFF0D9488).withValues(alpha: 0.2),
              checkmarkColor: const Color(0xFF0D9488),
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _operatingStates.add(st);
                  } else {
                    _operatingStates.remove(st);
                  }
                });
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  // --- Tab 2: Service Modules ---
  Widget _buildServicesTab(bool isDark) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        // Inventory Management Toggle Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _hasInventoryManagement
                ? const Color(0xFF10B981).withValues(alpha: 0.08)
                : const Color(0xFF64748B).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _hasInventoryManagement
                  ? const Color(0xFF10B981).withValues(alpha: 0.3)
                  : const Color(0xFF64748B).withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _hasInventoryManagement
                      ? const Color(0xFF10B981).withValues(alpha: 0.15)
                      : const Color(0xFF64748B).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.inventory_2_rounded,
                  color: _hasInventoryManagement ? const Color(0xFF10B981) : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Inventory & Stock Landed Cost Tracking',
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'When enabled, this merchant accesses multi-warehouse stock ledgers, weighted average valuation, itemized goods receipt invoices, and direct supplier management.',
                      style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _hasInventoryManagement,
                activeColor: const Color(0xFF10B981),
                onChanged: (v) => setState(() => _hasInventoryManagement = v),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Service Tier & Closers
        _buildResponsivePair(
          context,
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Service Tier', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              DropdownButtonFormField<String>(
                value: (_tier == 'enterprise' || _tier == 'standard_merchant') ? _tier : 'standard_merchant',
                items: const [
                  DropdownMenuItem(value: 'enterprise', child: Text('Enterprise Merchant')),
                  DropdownMenuItem(value: 'standard_merchant', child: Text('Standard Merchant')),
                ],
                onChanged: (v) => setState(() => _tier = v ?? _tier),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ],
          ),
          _buildTextField(
            label: 'Telesales Closers Limit',
            controller: _closerLimitController,
            hint: '250',
            isDark: isDark,
          ),
        ),
        const SizedBox(height: 16),

        // Services Checkboxes
        Text('Enabled Operational Services', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _buildServiceCheckbox('fulfillment', 'Physical Hub Warehousing & Shelf Storage'),
        _buildServiceCheckbox('delivery', 'Rider Last-Mile Dispatch & Cash Collection'),
        _buildServiceCheckbox('inventory_management', 'Goods Receipt Invoicing & Landed Cost'),
        _buildServiceCheckbox('returns_processing', 'Reverse Logistics & Product Restocking'),
      ],
    );
  }

  Widget _buildServiceCheckbox(String key, String title) {
    final isChecked = _servicesEnabled.contains(key);
    return CheckboxListTile(
      value: isChecked,
      title: Text(title, style: GoogleFonts.inter(fontSize: 12.5)),
      activeColor: const Color(0xFF0D9488),
      contentPadding: EdgeInsets.zero,
      dense: true,
      onChanged: (v) {
        setState(() {
          if (v == true) {
            _servicesEnabled.add(key);
          } else {
            _servicesEnabled.remove(key);
          }
        });
      },
    );
  }

  // --- Tab 3: Brand & Theming ---
  Widget _buildBrandTab(bool isDark) {
    final primaryPreview = _parseHex(_primaryColorController.text, const Color(0xFF0D9488));
    final secondaryPreview = _parseHex(_secondaryColorController.text, const Color(0xFF031632));
    final accentPreview = _parseHex(_accentColorController.text, const Color(0xFF10B981));
    final hasLogo = _logoUrlController.text.trim().isNotEmpty;

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        // Merchant Logo Upload Card
        Text('Company Corporate Logo', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildLogoPreview(60),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasLogo ? 'Corporate Logo Set' : 'No Logo Uploaded Yet',
                      style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Upload high-res PNG, JPG, WEBP, or SVG. It will appear across the DC Console merchant list, client portal, invoices, and shipping waybills.',
                      style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF94A3B8)),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _isUploadingLogo ? null : _pickLogoFile,
                          icon: _isUploadingLogo
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.file_upload_outlined, size: 16),
                          label: Text(_isUploadingLogo
                              ? 'Uploading to Cloud...'
                              : (hasLogo ? 'Change Logo File' : 'Upload Logo File')),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0D9488),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                        if (hasLogo && !_isUploadingLogo)
                          OutlinedButton.icon(
                            onPressed: () => setState(() => _logoUrlController.clear()),
                            icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFEF4444)),
                            label: Text('Remove Logo', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFFEF4444))),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFFEF4444)),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
        const SizedBox(height: 12),

        // Optional Direct Image URL
        _buildTextField(
          label: 'Or Specify Direct Image URL (Cloud CDN / Public Bucket)',
          controller: _logoUrlController,
          hint: 'https://example.com/logo.png',
          isDark: isDark,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 18),

        // Brand Presets
        Text('One-Tap Palette Presets', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _brandPresets.map((preset) {
            return ActionChip(
              avatar: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(color: preset['color'] as Color, shape: BoxShape.circle),
              ),
              label: Text(preset['name'] as String, style: GoogleFonts.inter(fontSize: 11.5)),
              onPressed: () {
                setState(() {
                  _primaryColorController.text = preset['primary'] as String;
                  _secondaryColorController.text = preset['secondary'] as String;
                  _accentColorController.text = preset['accent'] as String;
                });
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 18),

        // Color Hex Codes with Interactive Color Picker & Paste
        Text('Brand Color Palette & Swatches', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _buildResponsiveTriple(
          context,
          _buildColorSelectorTile(
            label: 'Primary Color',
            controller: _primaryColorController,
            isDark: isDark,
          ),
          _buildColorSelectorTile(
            label: 'Secondary Color',
            controller: _secondaryColorController,
            isDark: isDark,
          ),
          _buildColorSelectorTile(
            label: 'Accent Color',
            controller: _accentColorController,
            isDark: isDark,
          ),
        ),
        const SizedBox(height: 20),

        // Live Brand Preview Box
        Text('Live Theme Preview in Client Portal', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: secondaryPreview,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: primaryPreview, width: 2),
                ),
                child: _buildLogoPreview(42),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _companyNameController.text.isNotEmpty ? _companyNameController.text : 'Merchant Name',
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    Text('Executive Portal & Stock Custody', style: GoogleFonts.inter(fontSize: 11, color: Colors.white70)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: accentPreview,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('Live Theme', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- Tab 4: Tariffs & Banking ---
  Widget _buildTariffsTab(bool isDark) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        Text('Negotiated Operational Tariffs', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        _buildResponsiveTriple(
          context,
          _buildTextField(
            label: 'Delivery Fee (₦ / order)',
            controller: _deliveryFeeController,
            hint: '5000',
            isDark: isDark,
          ),
          _buildTextField(
            label: 'Failed Surcharge (₦ / attempt)',
            controller: _failedFeeController,
            hint: '1000',
            isDark: isDark,
          ),
          _buildTextField(
            label: 'Platform Charge (₦ / order)',
            controller: _platformFeeController,
            hint: '500',
            isDark: isDark,
          ),
        ),
        const SizedBox(height: 20),

        Text('Daily Remittance Banking Details', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        _buildTextField(
          label: 'Beneficiary Bank Name',
          controller: _bankNameController,
          hint: 'e.g. Access Bank, Zenith Bank',
          isDark: isDark,
        ),
        const SizedBox(height: 12),
        _buildResponsivePair(
          context,
          _buildTextField(
            label: 'Account Number (10-digit NUBAN)',
            controller: _accountNumberController,
            hint: '0123456789',
            isDark: isDark,
          ),
          _buildTextField(
            label: 'Verified Corporate Account Name',
            controller: _accountNameController,
            hint: 'Novacare Ltd',
            isDark: isDark,
          ),
          flex1: 2,
          flex2: 3,
        ),
        const SizedBox(height: 12),
        _buildResponsivePair(
          context,
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Settlement Frequency', style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              DropdownButtonFormField<String>(
                value: ['daily', 'weekly', 'biweekly'].contains(_settlementFrequency) ? _settlementFrequency : 'weekly',
                items: const [
                  DropdownMenuItem(value: 'daily', child: Text('Daily Closeout (10:00 PM)')),
                  DropdownMenuItem(value: 'weekly', child: Text('Weekly Remittance')),
                  DropdownMenuItem(value: 'biweekly', child: Text('Bi-Weekly Remittance')),
                ],
                onChanged: (v) => setState(() => _settlementFrequency = v ?? _settlementFrequency),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Settlement Day', style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              DropdownButtonFormField<String>(
                value: ['Everyday', 'Friday', 'Monday'].contains(_settlementDay) ? _settlementDay : 'Friday',
                items: const [
                  DropdownMenuItem(value: 'Everyday', child: Text('Everyday (Daily)')),
                  DropdownMenuItem(value: 'Friday', child: Text('Friday Closeout')),
                  DropdownMenuItem(value: 'Monday', child: Text('Monday Closeout')),
                ],
                onChanged: (v) => setState(() => _settlementDay = v ?? _settlementDay),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- Tab 5: Account Settings ---
  Widget _buildAccountSettingsTab(bool isDark) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        // 1. Account Operational Status & Deactivation Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: _isActive
                ? const Color(0xFF10B981).withValues(alpha: 0.08)
                : const Color(0xFFEF4444).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _isActive
                  ? const Color(0xFF10B981).withValues(alpha: 0.3)
                  : const Color(0xFFEF4444).withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _isActive
                          ? const Color(0xFF10B981).withValues(alpha: 0.15)
                          : const Color(0xFFEF4444).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isActive ? Icons.verified_user_rounded : Icons.block_rounded,
                      color: _isActive ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                      size: 22,
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
                              'Operational Status: ',
                              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: _isActive ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _isActive ? 'ACTIVE' : 'DEACTIVATED',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _isActive
                              ? 'This merchant account is fully active. Assigned telesales closers and merchant staff can login, view inventory, manage orders, and dispatches.'
                              : 'This merchant account is currently SUSPENDED. Portal logins, telesales closers, and delivery order dispatch are blocked.',
                          style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton.icon(
                    onPressed: () async {
                      final targetStatus = !_isActive;
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                          title: Text(targetStatus ? 'Reactivate Merchant Account?' : 'Deactivate Merchant Account?'),
                          content: Text(
                            targetStatus
                                ? 'Restore operational status to ${widget.client.companyName}? Merchant staff and telesales closers will be able to access the portal again.'
                                : 'Are you sure you want to DEACTIVATE ${widget.client.companyName}? Portal access will be suspended immediately.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(false),
                              child: const Text('Cancel'),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: targetStatus ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () => Navigator.of(ctx).pop(true),
                              child: Text(targetStatus ? 'Yes, Reactivate' : 'Yes, Deactivate'),
                            ),
                          ],
                        ),
                      );

                      if (confirm == true) {
                        setState(() => _isActive = targetStatus);
                        try {
                          await ref.read(dcConsoleProvider.notifier).toggleClientActiveStatus(widget.client.id, targetStatus);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: targetStatus ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                content: Text('Merchant account is now ${targetStatus ? "Active" : "Deactivated"}.'),
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(backgroundColor: const Color(0xFFEF4444), content: Text('Error updating status: $e')),
                            );
                          }
                        }
                      }
                    },
                    icon: Icon(
                      _isActive ? Icons.pause_circle_outline_rounded : Icons.play_circle_outline_rounded,
                      size: 16,
                    ),
                    label: Text(_isActive ? 'Deactivate Merchant Account' : 'Reactivate Merchant Account'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isActive ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // 2. Password Reset via Email
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.mark_email_read_rounded, color: Color(0xFF0284C7), size: 20),
                  const SizedBox(width: 8),
                  Text('Send Password Reset Link', style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Dispatches an automated password reset email with secure one-time instructions to ${_emailController.text.trim()}.',
                style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _isResettingPassword
                    ? null
                    : () async {
                        final email = _emailController.text.trim();
                        if (email.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please specify a valid email address first.')),
                          );
                          return;
                        }
                        setState(() => _isResettingPassword = true);
                        try {
                          await ref.read(dcConsoleProvider.notifier).sendClientPasswordResetEmail(email);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: const Color(0xFF10B981),
                                content: Text('Password reset link sent to $email successfully!'),
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(backgroundColor: const Color(0xFFEF4444), content: Text('Reset email failed: $e')),
                            );
                          }
                        } finally {
                          if (mounted) setState(() => _isResettingPassword = false);
                        }
                      },
                icon: _isResettingPassword
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send_rounded, size: 15),
                label: Text(_isResettingPassword ? 'Sending...' : 'Send Password Reset Email'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 3. Direct Admin Password Override
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.key_rounded, color: Color(0xFFF59E0B), size: 20),
                  const SizedBox(width: 8),
                  Text('Direct Admin Password Override', style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Directly set a new password for this merchant account without waiting for email verification.',
                style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
              ),
              const SizedBox(height: 14),
              _buildResponsivePair(
                context,
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('New Password', style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    TextFormField(
                      controller: _adminNewPasswordController,
                      obscureText: _obscureAdminPassword,
                      decoration: InputDecoration(
                        hintText: '••••••••',
                        filled: true,
                        fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        suffixIcon: IconButton(
                          icon: Icon(_obscureAdminPassword ? Icons.visibility_off : Icons.visibility, size: 18),
                          onPressed: () => setState(() => _obscureAdminPassword = !_obscureAdminPassword),
                        ),
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Confirm New Password', style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    TextFormField(
                      controller: _adminConfirmPasswordController,
                      obscureText: _obscureAdminPassword,
                      decoration: InputDecoration(
                        hintText: '••••••••',
                        filled: true,
                        fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              ElevatedButton.icon(
                onPressed: _isUpdatingPassword
                    ? null
                    : () async {
                        final newPass = _adminNewPasswordController.text.trim();
                        final confirmPass = _adminConfirmPasswordController.text.trim();
                        if (newPass.length < 6) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Password must be at least 6 characters long.')),
                          );
                          return;
                        }
                        if (newPass != confirmPass) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Passwords do not match.')),
                          );
                          return;
                        }
                        setState(() => _isUpdatingPassword = true);
                        try {
                          await ref.read(dcConsoleProvider.notifier).adminSetClientPassword(
                            clientId: widget.client.id,
                            email: _emailController.text.trim(),
                            newPassword: newPass,
                          );
                          _adminNewPasswordController.clear();
                          _adminConfirmPasswordController.clear();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                backgroundColor: Color(0xFF10B981),
                                content: Text('Merchant password successfully updated!'),
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(backgroundColor: const Color(0xFFEF4444), content: Text('Password update error: $e')),
                            );
                          }
                        } finally {
                          if (mounted) setState(() => _isUpdatingPassword = false);
                        }
                      },
                icon: _isUpdatingPassword
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.lock_reset_rounded, size: 16),
                label: Text(_isUpdatingPassword ? 'Saving Password...' : 'Save New Password Directly'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF59E0B),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- Brand Helpers: Logo & Colors ---
  Widget _buildLogoPreview(double size) {
    return ClientLogoWidget(
      logoUrl: _logoUrlController.text.trim(),
      companyName: _companyNameController.text.trim().isNotEmpty
          ? _companyNameController.text.trim()
          : widget.client.companyName,
      size: size,
      borderRadius: 12,
      brandColor: _parseHex(_primaryColorController.text, const Color(0xFF0D9488)),
    );
  }

  Future<void> _pickLogoFile() async {
    try {
      final result = await FilePickerPlatform.instance.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'jpeg', 'webp', 'svg'],
      );
      if (result.isNotEmpty) {
        final file = result.first;
        final bytes = await file.readAsBytes();
        if (bytes.isNotEmpty) {
          setState(() => _isUploadingLogo = true);
          final ext = (file.extension ?? 'png').toLowerCase();
          final mime = ext == 'svg'
              ? 'image/svg+xml'
              : (ext == 'jpg' || ext == 'jpeg'
                  ? 'image/jpeg'
                  : (ext == 'webp' ? 'image/webp' : 'image/png'));

          String finalLogoUrl = '';
          try {
            final fileName = 'logo_${widget.client.id}_${DateTime.now().millisecondsSinceEpoch}.$ext';
            final storagePath = 'client_logos/$fileName';
            final db = Supabase.instance.client;
            await db.storage.from(SupabaseConstants.avatarsBucket).uploadBinary(
              storagePath,
              bytes,
              fileOptions: FileOptions(
                contentType: mime,
                upsert: true,
              ),
            );
            finalLogoUrl = db.storage.from(SupabaseConstants.avatarsBucket).getPublicUrl(storagePath);
            debugPrint('[DC_EDIT_CLIENT] ✅ Corporate logo uploaded to storage: $finalLogoUrl');
          } catch (storageErr) {
            debugPrint('[DC_EDIT_CLIENT] ℹ️ Storage upload fallback to data URI: $storageErr');
            final base64String = base64Encode(bytes);
            finalLogoUrl = 'data:$mime;base64,$base64String';
          }

          setState(() {
            _isUploadingLogo = false;
            _logoUrlController.text = finalLogoUrl;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: const Color(0xFF10B981),
                content: Text('✓ Corporate logo ready! Remember to click "Save Changes" below to persist.'),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingLogo = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFEF4444),
            content: Text('Failed to pick logo image: $e'),
          ),
        );
      }
    }
  }

  Widget _buildColorSelectorTile({
    required String label,
    required TextEditingController controller,
    required bool isDark,
  }) {
    final currentColor = _parseHex(controller.text, const Color(0xFF0D9488));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => _showColorPickerDialog(label, controller),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: currentColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: currentColor.withValues(alpha: 0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
                Text(
                  controller.text.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Pick or Paste Hex Color',
            icon: const Icon(Icons.colorize_rounded, size: 20),
            color: currentColor,
            onPressed: () => _showColorPickerDialog(label, controller),
          ),
        ],
      ),
    );
  }

  Future<void> _showColorPickerDialog(String label, TextEditingController controller) async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final initialColor = _parseHex(controller.text, const Color(0xFF0D9488));
    Color selectedColor = initialColor;
    final hexTextController = TextEditingController(text: controller.text.replaceAll('#', '').trim());

    final presetColors = [
      const Color(0xFF0D9488), // Emerald Teal
      const Color(0xFF0284C7), // Sky Blue
      const Color(0xFF2563EB), // Blue
      const Color(0xFF4F46E5), // Indigo
      const Color(0xFF7C3AED), // Violet
      const Color(0xFF9333EA), // Purple
      const Color(0xFFC026D3), // Fuchsia
      const Color(0xFFDB2777), // Pink
      const Color(0xFFE11D48), // Rose
      const Color(0xFFDC2626), // Red
      const Color(0xFFEA580C), // Orange
      const Color(0xFFD97706), // Amber
      const Color(0xFF16A34A), // Green
      const Color(0xFF059669), // Emerald
      const Color(0xFF0891B2), // Cyan
      const Color(0xFF0284C7), // Light Blue
      const Color(0xFF475569), // Slate
      const Color(0xFF334155), // Dark Slate
      const Color(0xFF1E293B), // Navy Slate
      const Color(0xFF0F172A), // Midnight
      const Color(0xFF000000), // Black
      const Color(0xFF64748B), // Neutral
      const Color(0xFF10B981), // Mint
      const Color(0xFFF59E0B), // Golden
    ];

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            void updateFromHex(String hex) {
              final clean = hex.replaceAll('#', '').trim();
              if (clean.length == 6 || clean.length == 8) {
                try {
                  final parsed = Color(int.parse('0xFF${clean.substring(clean.length - 6)}'));
                  setDialogState(() {
                    selectedColor = parsed;
                  });
                } catch (_) {}
              }
            }

            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: selectedColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Choose $label',
                      style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 380,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Comparison Preview
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              children: [
                                Text('Current', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8))),
                                const SizedBox(height: 4),
                                Container(
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: initialColor,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Icon(Icons.arrow_forward_rounded, size: 16, color: Color(0xFF94A3B8)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              children: [
                                Text('Selected', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8))),
                                const SizedBox(height: 4),
                                Container(
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: selectedColor,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Color Palette Swatches
                    Text('Palette Swatches', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: presetColors.map((color) {
                        final isSelected = selectedColor.value == color.value;
                        final hexCode = '#${color.value.toRadixString(16).substring(2).toUpperCase()}';
                        return GestureDetector(
                          onTap: () {
                            setDialogState(() {
                              selectedColor = color;
                              hexTextController.text = hexCode.replaceAll('#', '');
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected ? Colors.white : Colors.transparent,
                                width: 2.5,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: color.withValues(alpha: 0.6),
                                        blurRadius: 8,
                                        spreadRadius: 1,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: isSelected
                                ? const Icon(Icons.check, size: 16, color: Colors.white)
                                : null,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    // Hex Input & Clipboard Paste
                    Text('Hex Color Code', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: hexTextController,
                            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold),
                            decoration: InputDecoration(
                              prefixText: '# ',
                              prefixStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, color: const Color(0xFF94A3B8)),
                              hintText: '0D9488',
                              filled: true,
                              fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                            onChanged: (val) => updateFromHex(val),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: () async {
                            final data = await Clipboard.getData(Clipboard.kTextPlain);
                            if (data != null && data.text != null) {
                              final text = data.text!.replaceAll('#', '').trim();
                              hexTextController.text = text;
                              updateFromHex(text);
                            }
                          },
                          icon: const Icon(Icons.content_paste_rounded, size: 16),
                          label: Text('Paste', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0D9488),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text('Cancel', style: GoogleFonts.inter(color: const Color(0xFF94A3B8))),
                ),
                ElevatedButton(
                  onPressed: () {
                    final hex = '#${selectedColor.value.toRadixString(16).substring(2).toUpperCase()}';
                    setState(() {
                      controller.text = hex;
                    });
                    Navigator.of(ctx).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D9488),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text('Apply Color', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildResponsivePair(
    BuildContext context,
    Widget first,
    Widget second, {
    int flex1 = 1,
    int flex2 = 1,
    double spacing = 12,
  }) {
    final isNarrow = MediaQuery.of(context).size.width < 560;
    if (isNarrow) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          first,
          SizedBox(height: spacing),
          second,
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: flex1, child: first),
        SizedBox(width: spacing),
        Expanded(flex: flex2, child: second),
      ],
    );
  }

  Widget _buildResponsiveTriple(
    BuildContext context,
    Widget first,
    Widget second,
    Widget third, {
    double spacing = 12,
  }) {
    final isNarrow = MediaQuery.of(context).size.width < 560;
    if (isNarrow) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          first,
          SizedBox(height: spacing),
          second,
          SizedBox(height: spacing),
          third,
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: first),
        SizedBox(width: spacing),
        Expanded(child: second),
        SizedBox(width: spacing),
        Expanded(child: third),
      ],
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required String hint,
    required bool isDark,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          style: GoogleFonts.inter(fontSize: 13),
          validator: validator,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
            filled: true,
            fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
      ],
    );
  }
}
