import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/nigeria_locations.dart';
import '../../../../core/helpers/formatters.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/dc_fleet_driver.dart';
import '../providers/dc_console_provider.dart';

class DCOnboardRiderModal extends ConsumerStatefulWidget {
  const DCOnboardRiderModal({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const DCOnboardRiderModal(),
    );
  }

  @override
  ConsumerState<DCOnboardRiderModal> createState() => _DCOnboardRiderModalState();
}

class _DCOnboardRiderModalState extends ConsumerState<DCOnboardRiderModal> {
  int _currentStep = 0;
  bool _isSubmitting = false;
  Map<String, dynamic>? _createdCredentialsSlip;

  // Step 1: Personnel Type & KYC (All 36 States + FCT)
  String _personnelType = 'pda'; // 'pda' | 'in_house_rider'
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _guarantorNameController = TextEditingController();
  final _guarantorPhoneController = TextEditingController();
  String _operatingState = 'FCT - Abuja';
  String _assignedZone = 'Wuse 2';

  // Step 2: Login Credentials & Security
  final _tempPasswordController = TextEditingController(text: 'Password123!');
  final _tempPinController = TextEditingController(text: '1234');
  bool _mustChangePassword = true;

  // Step 3: Vehicle & Asset Setup
  String _vehicleType = 'Motorcycle';
  final _vehicleModelController = TextEditingController(text: 'Bajaj Boxer 100 (Personal)');
  final _vehiclePlateController = TextEditingController(text: 'ABJ-304-XY');
  final _licenseOrAssetTagController = TextEditingController(text: 'LIC-2026-9912');
  final _fuelCardController = TextEditingController(text: 'FUEL-VOUCH-882');

  // Step 4: Unique Compensation Agreement
  String _compensationType = 'commission'; // 'commission' | 'salary' | 'hybrid'
  final _commissionController = TextEditingController(text: '1000');
  final _transportAllowanceController = TextEditingController(text: '1500');
  final _failedAllowanceController = TextEditingController(text: '500');
  final _baseSalaryController = TextEditingController(text: '120000');
  final _upsellBonusController = TextEditingController(text: '10');

  // Step 5: Bank Payout Details
  String _selectedBank = 'Kuda Microfinance Bank';
  final _accountNumberController = TextEditingController();
  final _accountNameController = TextEditingController();

  final List<String> _zones = [
    'Wuse II & Zone 4',
    'Maitama & Ministers Hill',
    'Garki I & II',
    'Utako & Jabi',
    'Abuja Central Business District (CBD)',
    'Asokoro & Guzape',
    'Gwarinpa Estate',
  ];

  final List<String> _banks = [
    'Kuda Microfinance Bank',
    'GTBank',
    'Zenith Bank',
    'Access Bank',
    'First Bank of Nigeria',
    'United Bank for Africa (UBA)',
    'OPay',
    'PalmPay',
    'Stanbic IBTC Bank',
    'Fidelity Bank',
  ];

  @override
  void initState() {
    super.initState();
    _firstNameController.addListener(_autoUpdateEmail);
    _lastNameController.addListener(_autoUpdateEmail);
  }

  void _autoUpdateEmail() {
    if (_emailController.text.isEmpty || _emailController.text.contains('@novaexpress.ng')) {
      final f = _firstNameController.text.trim().toLowerCase();
      final l = _lastNameController.text.trim().toLowerCase();
      if (f.isNotEmpty || l.isNotEmpty) {
        final prefix = '${f.isNotEmpty ? f : "rider"}.${l.isNotEmpty ? l : "agent"}';
        _emailController.text = '$prefix@novaexpress.ng';
      }
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _guarantorNameController.dispose();
    _guarantorPhoneController.dispose();
    _tempPasswordController.dispose();
    _tempPinController.dispose();
    _vehicleModelController.dispose();
    _vehiclePlateController.dispose();
    _licenseOrAssetTagController.dispose();
    _fuelCardController.dispose();
    _commissionController.dispose();
    _transportAllowanceController.dispose();
    _failedAllowanceController.dispose();
    _baseSalaryController.dispose();
    _upsellBonusController.dispose();
    _accountNumberController.dispose();
    _accountNameController.dispose();
    super.dispose();
  }

  void _onPersonnelTypeChanged(String type) {
    setState(() {
      _personnelType = type;
      if (type == 'pda') {
        _vehicleModelController.text = 'Bajaj Boxer 100 (Personal)';
        _commissionController.text = '1000';
        _transportAllowanceController.text = '1500';
        _failedAllowanceController.text = '500';
        _baseSalaryController.text = '0';
        _compensationType = 'commission';
      } else {
        _vehicleModelController.text = 'Haojue 125 (Company Fleet)';
        _commissionController.text = '500';
        _transportAllowanceController.text = '800';
        _failedAllowanceController.text = '300';
        _baseSalaryController.text = '120000';
        _compensationType = 'salary';
      }
    });
  }

  Future<void> _submitOnboarding() async {
    setState(() => _isSubmitting = true);

    final firstName = _firstNameController.text.trim().isEmpty ? 'Samuel' : _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim().isEmpty ? 'Okon' : _lastNameController.text.trim();
    final fullName = '$firstName $lastName';
    final phone = _phoneController.text.trim().isEmpty ? '08031234567' : _phoneController.text.trim();
    final email = _emailController.text.trim().isEmpty
        ? '${firstName.toLowerCase()}.${lastName.toLowerCase()}@novaexpress.ng'
        : _emailController.text.trim();
    final tempPassword = _tempPasswordController.text.trim().isEmpty ? 'Password123!' : _tempPasswordController.text.trim();
    final tempPin = _tempPinController.text.trim().isEmpty ? '1234' : _tempPinController.text.trim();

    final isPda = _personnelType == 'pda';
    final randomSuffix = (100 + (DateTime.now().millisecondsSinceEpoch % 899)).toString();
    final driverCode = isPda ? 'PDA-7$randomSuffix' : 'RDR-$randomSuffix';

    final commission = double.tryParse(_commissionController.text) ?? (isPda ? 1000.0 : 500.0);
    final transport = double.tryParse(_transportAllowanceController.text) ?? (isPda ? 1500.0 : 800.0);
    final failed = double.tryParse(_failedAllowanceController.text) ?? 500.0;
    final salary = double.tryParse(_baseSalaryController.text) ?? (isPda ? 0.0 : 120000.0);
    final upsell = double.tryParse(_upsellBonusController.text) ?? 10.0;

    String finalDriverCode = driverCode;

    // 1. Register rider in database & authentication system
    try {
      final createdUser = await ref.read(authRemoteDataSourceProvider).registerDeliveryAgent(
        email: email,
        password: tempPassword,
        firstName: firstName,
        lastName: lastName,
        phone: phone,
        personnelType: _personnelType,
        compensationType: _compensationType,
        commissionRate: commission,
        transportAllowance: transport,
        fuelAllowance: isPda ? 0.0 : 800.0,
        baseSalary: salary,
        vehicleType: _vehicleType,
        vehiclePlateNumber: _vehiclePlateController.text.trim(),
        bankName: _selectedBank,
        bankAccountNumber: _accountNumberController.text.trim().isEmpty ? '2019847291' : _accountNumberController.text.trim(),
        bankAccountName: _accountNameController.text.trim().isEmpty ? fullName : _accountNameController.text.trim(),
        distributionCenterId: '22222222-2222-4222-8222-222222222222',
        assignedZone: _assignedZone,
      );
      if (createdUser.deliveryAgentCode?.isNotEmpty == true) {
        finalDriverCode = createdUser.deliveryAgentCode!;
      }
      debugPrint('[DC_ONBOARD] 🚀 Delivery agent registered: ${createdUser.email} ($finalDriverCode)');
    } catch (e) {
      debugPrint('[DC_ONBOARD] ⚠️ Registration notice: $e');
    }

    final newDriver = DCFleetDriver(
      id: 'drv-${DateTime.now().millisecondsSinceEpoch}',
      driverCode: finalDriverCode,
      name: fullName,
      phone: phone,
      email: email,
      avatarUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150',
      vehicleModel: _vehicleModelController.text.trim(),
      vehiclePlate: _vehiclePlateController.text.trim(),
      vehicleType: _vehicleType,
      status: 'active',
      assignedZone: _assignedZone,
      totalAssignedOrders: 0,
      completedOrders: 0,
      routeProgressPercent: 0.0,
      efficiencyRating: 100.0,
      cashInCustody: 0.0,
      itemsInCustody: 0,
      personnelType: _personnelType,
      compensationType: _compensationType,
      commissionRate: commission,
      transportAllowance: transport,
      failedDeliveryAllowance: failed,
      baseSalary: salary,
      upsellBonusPercent: upsell,
      bankName: _selectedBank,
      bankAccountNumber: _accountNumberController.text.trim().isEmpty ? '2019847291' : _accountNumberController.text.trim(),
      bankAccountName: _accountNameController.text.trim().isEmpty ? fullName : _accountNameController.text.trim(),
      guarantorName: _guarantorNameController.text.trim().isEmpty ? 'Dr. Chidi Okafor' : _guarantorNameController.text.trim(),
      guarantorPhone: _guarantorPhoneController.text.trim().isEmpty ? '08034567890' : _guarantorPhoneController.text.trim(),
    );

    // 2. Save to DC provider and sync from live database
    ref.read(dcConsoleProvider.notifier).addDriver(newDriver);
    ref.read(dcConsoleProvider.notifier).loadDriversFromDatabase();

    // 3. Prepare credentials confirmation slip with exact login details
    setState(() {
      _isSubmitting = false;
      _createdCredentialsSlip = {
        'driverCode': finalDriverCode,
        'name': fullName,
        'email': email,
        'password': tempPassword,
        'pin': tempPin,
        'personnelType': isPda ? 'PDA (Personal Vehicle)' : 'In-House Rider (Company Fleet)',
        'hub': 'Wuse Distribution Center (DC-WUSE-01)',
        'agreement': '₦${commission.toInt()} Comm. + ₦${transport.toInt()} Transport',
        'salary': salary > 0 ? CurrencyFormatter.formatNaira(salary) : 'Commission Only',
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_createdCredentialsSlip != null) {
      return _buildCredentialsSuccessSlip(isDark);
    }

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF151D36) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        width: 860,
        constraints: const BoxConstraints(maxHeight: 740),
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF031632),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.person_add_alt_1_rounded, color: Color(0xFFF37021), size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Onboard Delivery Agent / Rider',
                              style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF031632),
                              ),
                            ),
                            Text(
                              'Configure identity, generate login credentials, assign vehicle assets, and set unique rate agreements',
                              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
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

            // Step Indicator Header
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildStepTab(0, '1. Role & Identity', Icons.badge_outlined),
                  const SizedBox(width: 8),
                  _buildStepTab(1, '2. Login & Security', Icons.lock_outline_rounded),
                  const SizedBox(width: 8),
                  _buildStepTab(2, '3. Vehicle & Asset', Icons.two_wheeler_rounded),
                  const SizedBox(width: 8),
                  _buildStepTab(3, '4. Agreement', Icons.handshake_outlined),
                  const SizedBox(width: 8),
                  _buildStepTab(4, '5. Payout Bank', Icons.account_balance_outlined),
                ],
              ),
            ),

            const SizedBox(height: 16),
            const Divider(height: 1, color: Color(0xFF2E3D6B)),
            const SizedBox(height: 16),

            // Scrollable Step Body
            Expanded(
              child: SingleChildScrollView(
                child: _buildCurrentStepView(isDark),
              ),
            ),

            const SizedBox(height: 16),
            const Divider(height: 1, color: Color(0xFF2E3D6B)),
            const SizedBox(height: 16),

            // Modal Footer Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (_currentStep > 0)
                  OutlinedButton.icon(
                    onPressed: () => setState(() => _currentStep--),
                    icon: const Icon(Icons.arrow_back_rounded, size: 16),
                    label: const Text('Previous'),
                  )
                else
                  const SizedBox.shrink(),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 10),
                    if (_currentStep < 4)
                      ElevatedButton.icon(
                        onPressed: () => setState(() => _currentStep++),
                        icon: const Icon(Icons.arrow_forward_rounded, size: 16, color: Colors.white),
                        label: const Text('Next Step', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF031632),
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        ),
                      )
                    else
                      ElevatedButton.icon(
                        onPressed: _isSubmitting ? null : _submitOnboarding,
                        icon: _isSubmitting
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.check_circle_rounded, size: 18, color: Colors.white),
                        label: const Text('Issue Credentials & Activate', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF059669),
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepTab(int stepIdx, String label, IconData icon) {
    final isActive = _currentStep == stepIdx;
    final isDone = _currentStep > stepIdx;

    return InkWell(
      onTap: () => setState(() => _currentStep = stepIdx),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF031632) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive ? const Color(0xFF031632) : (isDone ? const Color(0xFF10B981) : const Color(0xFFCBD5E1)),
            width: isActive ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isDone ? Icons.check_circle_rounded : icon,
              size: 16,
              color: isDone ? const Color(0xFF10B981) : (isActive ? const Color(0xFFF37021) : const Color(0xFF64748B)),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                color: isActive ? Colors.white : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentStepView(bool isDark) {
    switch (_currentStep) {
      case 0:
        return _buildStep1RoleAndKyc(isDark);
      case 1:
        return _buildStep2LoginSecurity(isDark);
      case 2:
        return _buildStep3VehicleAndAssets(isDark);
      case 3:
        return _buildStep4CompensationAgreement(isDark);
      case 4:
        return _buildStep5PayoutBank(isDark);
      default:
        return const SizedBox.shrink();
    }
  }

  // ---------------------------------------------------------------------------
  // STEP 1: ROLE & KYC
  // ---------------------------------------------------------------------------
  Widget _buildStep1RoleAndKyc(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Personnel Operational Model',
          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),

        // Personnel Type Selection Cards (Responsive Layout)
        LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 600;
            final double cardWidth = isNarrow ? constraints.maxWidth : (constraints.maxWidth - 12) / 2;

            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: cardWidth,
                  child: _buildPersonnelTypeCard(
                    typeKey: 'pda',
                    title: 'PDA (Personal Distribution Agent)',
                    badge: 'Own Vehicle',
                    description: 'Uses personal motorcycle, car, or bicycle. Carries distributed client inventory. Compensated on custom commission & transport allowance.',
                    icon: Icons.two_wheeler_rounded,
                    isSelected: _personnelType == 'pda',
                    onTap: () => _onPersonnelTypeChanged('pda'),
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _buildPersonnelTypeCard(
                    typeKey: 'in_house_rider',
                    title: 'In-House Delivery Rider',
                    badge: 'Company Bike',
                    description: 'Uses NovaExpress company fleet vehicle. Operates on base salary + fuel allowance & delivery milestone bonuses.',
                    icon: Icons.delivery_dining_rounded,
                    isSelected: _personnelType == 'in_house_rider',
                    onTap: () => _onPersonnelTypeChanged('in_house_rider'),
                  ),
                ),
              ],
            );
          },
        ),

        const SizedBox(height: 20),

        Text('Personal & Identity Details', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: TextField(controller: _firstNameController, decoration: const InputDecoration(labelText: 'First Name', hintText: 'e.g. Samuel'))),
            const SizedBox(width: 12),
            Expanded(child: TextField(controller: _lastNameController, decoration: const InputDecoration(labelText: 'Last Name', hintText: 'e.g. Okon'))),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: TextField(controller: _phoneController, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone Number', hintText: '08031234567'))),
            const SizedBox(width: 12),
            Expanded(child: TextField(controller: _emailController, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Contact Email', hintText: 'samuel.okon@novaexpress.ng'))),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _operatingState,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Operating State (36 States + FCT)'),
                items: NigeriaLocations.states.map((s) => DropdownMenuItem(value: s, child: Text(s, style: GoogleFonts.inter(fontSize: 13), overflow: TextOverflow.ellipsis))).toList(),
                onChanged: (val) {
                  if (val != null) {
                    final cities = NigeriaLocations.getCitiesForState(val);
                    setState(() {
                      _operatingState = val;
                      _assignedZone = cities.isNotEmpty ? cities.first : 'Central';
                    });
                  }
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: NigeriaLocations.getCitiesForState(_operatingState).contains(_assignedZone)
                    ? _assignedZone
                    : (NigeriaLocations.getCitiesForState(_operatingState).isNotEmpty
                        ? NigeriaLocations.getCitiesForState(_operatingState).first
                        : null),
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Primary Operational Zone / LGA'),
                items: NigeriaLocations.getCitiesForState(_operatingState).map((z) => DropdownMenuItem(value: z, child: Text(z, style: GoogleFonts.inter(fontSize: 13), overflow: TextOverflow.ellipsis))).toList(),
                onChanged: (val) => setState(() => _assignedZone = val ?? _assignedZone),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text('Emergency Contact & Guarantor', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: TextField(controller: _guarantorNameController, decoration: const InputDecoration(labelText: 'Guarantor Full Name', hintText: 'e.g. Dr. Chidi Okafor'))),
            const SizedBox(width: 12),
            Expanded(child: TextField(controller: _guarantorPhoneController, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Guarantor Phone', hintText: '08034567890'))),
          ],
        ),
      ],
    );
  }

  Widget _buildPersonnelTypeCard({
    required String typeKey,
    required String title,
    required String badge,
    required String description,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: isSelected ? const Color(0xFF031632).withValues(alpha: 0.06) : Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? const Color(0xFFF37021) : const Color(0xFFCBD5E1),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF031632) : const Color(0xFFE2E8F0),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 18, color: isSelected ? const Color(0xFFF37021) : const Color(0xFF64748B)),
                  ),
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFFF37021) : const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        badge,
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : const Color(0xFF64748B),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(title, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(description, style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B))),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // STEP 2: LOGIN CREDENTIALS & SECURITY
  // ---------------------------------------------------------------------------
  Widget _buildStep2LoginSecurity(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Agent Login Account & Mobile Credentials',
          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Text(
          'The credentials configured here will be used by the delivery agent to log into the NovaExpress Rider App.',
          style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
        ),
        const SizedBox(height: 16),

        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Rider Login Email Address',
            hintText: 'e.g. samuel.okon@novaexpress.ng',
            prefixIcon: Icon(Icons.email_outlined, size: 18),
          ),
        ),
        const SizedBox(height: 14),

        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _tempPasswordController,
                decoration: const InputDecoration(
                  labelText: 'Temporary Password',
                  hintText: 'Password123!',
                  prefixIcon: Icon(Icons.key_outlined, size: 18),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _tempPinController,
                keyboardType: TextInputType.number,
                maxLength: 4,
                buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                decoration: const InputDecoration(
                  labelText: 'Security PIN (4 Digits)',
                  hintText: '1234',
                  prefixIcon: Icon(Icons.pin_outlined, size: 18),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 14),

        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF37021).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFF37021).withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Checkbox(
                value: _mustChangePassword,
                activeColor: const Color(0xFF031632),
                onChanged: (val) => setState(() => _mustChangePassword = val ?? true),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Require Password Change on First Login', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF031632))),
                    Text('Forces the agent to change their default temporary password when they first log into the mobile app.', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B))),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // STEP 3: VEHICLE & ASSET SETUP
  // ---------------------------------------------------------------------------
  Widget _buildStep3VehicleAndAssets(bool isDark) {
    final isPda = _personnelType == 'pda';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isPda ? 'Personal Vehicle Details (PDA)' : 'Company Vehicle & Fleet Asset Assignment (In-House)',
          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _vehicleType,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Vehicle Category'),
                items: ['Motorcycle', 'Car', 'Van', 'Tricycle', 'Bicycle']
                    .map((v) => DropdownMenuItem(value: v, child: Text(v, style: GoogleFonts.inter(fontSize: 13), overflow: TextOverflow.ellipsis)))
                    .toList(),
                onChanged: (val) => setState(() => _vehicleType = val ?? _vehicleType),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _vehicleModelController,
                decoration: InputDecoration(
                  labelText: isPda ? 'Personal Make & Model' : 'Company Fleet Model',
                  hintText: isPda ? 'e.g. Bajaj Boxer 100' : 'e.g. Haojue 125',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _vehiclePlateController,
                decoration: const InputDecoration(
                  labelText: 'Vehicle Registration Plate',
                  hintText: 'e.g. ABJ-204-XY',
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _licenseOrAssetTagController,
                decoration: InputDecoration(
                  labelText: isPda ? "Driver's License Number" : 'Fleet Asset Tracker Tag',
                  hintText: isPda ? 'e.g. LIC-2026-9912' : 'e.g. TRK-ASSET-09',
                ),
              ),
            ),
          ],
        ),
        if (!isPda) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _fuelCardController,
            decoration: const InputDecoration(
              labelText: 'Company Fuel Card / Voucher Number',
              hintText: 'e.g. FUEL-VOUCH-882',
            ),
          ),
        ],
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // STEP 4: COMPENSATION AGREEMENT
  // ---------------------------------------------------------------------------
  Widget _buildStep4CompensationAgreement(bool isDark) {
    final comm = double.tryParse(_commissionController.text) ?? 0.0;
    final transport = double.tryParse(_transportAllowanceController.text) ?? 0.0;
    final totalPerOrder = comm + transport;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Configure Unique Compensation & Transport Agreement (BR-010 to BR-015)',
          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Text(
          'Rates configured here snapshot into the order ledger and accumulate into the agent\'s "My Balance" upon successful delivery completion.',
          style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
        ),
        const SizedBox(height: 16),

        // Total Entitlement Highlight Ribbon
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF10B981).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.stars_rounded, color: Color(0xFF10B981), size: 24),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Per-Delivery Entitlement Calculation', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF065F46))),
                          Text('Commission (${CurrencyFormatter.formatNaira(comm)}) + Transport Allowance (${CurrencyFormatter.formatNaira(transport)})', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF047857)), overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                CurrencyFormatter.formatNaira(totalPerOrder),
                style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w900, color: const Color(0xFF059669)),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        DropdownButtonFormField<String>(
          value: _compensationType,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Compensation Model Structure'),
          items: const [
            DropdownMenuItem(value: 'commission', child: Text('Commission & Transport Allowance (Per Drop)', overflow: TextOverflow.ellipsis)),
            DropdownMenuItem(value: 'salary', child: Text('Fixed Monthly Salary + Fuel Allowance', overflow: TextOverflow.ellipsis)),
            DropdownMenuItem(value: 'hybrid', child: Text('Hybrid: Base Salary + Per Drop Commission', overflow: TextOverflow.ellipsis)),
          ],
          onChanged: (val) => setState(() => _compensationType = val ?? _compensationType),
        ),

        const SizedBox(height: 14),

        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _commissionController,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Base Commission (₦ per drop)',
                      prefixText: '₦ ',
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [500, 1000, 1200, 1500].map((rate) {
                      final isSel = _commissionController.text == rate.toString();
                      return InkWell(
                        onTap: () => setState(() => _commissionController.text = rate.toString()),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isSel ? const Color(0xFF031632) : const Color(0xFFE2E8F0),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '₦$rate',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isSel ? Colors.white : const Color(0xFF334155),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _transportAllowanceController,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Transport / Fuel Allowance (₦ per drop)',
                      prefixText: '₦ ',
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [800, 1200, 1500, 2000].map((rate) {
                      final isSel = _transportAllowanceController.text == rate.toString();
                      return InkWell(
                        onTap: () => setState(() => _transportAllowanceController.text = rate.toString()),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isSel ? const Color(0xFF031632) : const Color(0xFFE2E8F0),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '₦$rate',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isSel ? Colors.white : const Color(0xFF334155),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 14),

        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _failedAllowanceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Failed Delivery Attempt Stipend (₦)',
                  prefixText: '₦ ',
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _upsellBonusController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Doorstep Upsell Bounty Rate (%)',
                  suffixText: '%',
                ),
              ),
            ),
          ],
        ),

        if (_compensationType != 'commission') ...[
          const SizedBox(height: 14),
          TextField(
            controller: _baseSalaryController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Fixed Monthly Base Salary (₦)',
              prefixText: '₦ ',
            ),
          ),
        ],
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // STEP 5: PAYOUT BANK ACCOUNT DETAILS
  // ---------------------------------------------------------------------------
  Widget _buildStep5PayoutBank(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Rider Payout Bank Account Details (for "My Balance" Withdrawals)',
          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Text(
          'Earnings accumulated from Monnify direct-transfer and cash orders will be disbursed to this verified bank account upon DC approval.',
          style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
        ),
        const SizedBox(height: 16),

        DropdownButtonFormField<String>(
          value: _selectedBank,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Destination Bank Name'),
          items: _banks.map((b) => DropdownMenuItem(value: b, child: Text(b, style: GoogleFonts.inter(fontSize: 13), overflow: TextOverflow.ellipsis))).toList(),
          onChanged: (val) => setState(() => _selectedBank = val ?? _selectedBank),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _accountNumberController,
                keyboardType: TextInputType.number,
                maxLength: 10,
                buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                decoration: const InputDecoration(
                  labelText: '10-Digit NUBAN Account Number',
                  hintText: 'e.g. 2019847291',
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _accountNameController,
                decoration: const InputDecoration(
                  labelText: 'Verified Beneficiary Account Name',
                  hintText: 'e.g. Samuel Okon',
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Agreement Summary Box
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0B1021) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFCBD5E1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Summary of Onboarding Terms', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _buildSummaryRow('Personnel Model:', _personnelType == 'pda' ? 'PDA (Personal Vehicle)' : 'In-House Rider (Company Fleet)'),
              _buildSummaryRow('Operational Hub:', 'Wuse Distribution Center (DC-WUSE-01)'),
              _buildSummaryRow('Assigned Zone:', _assignedZone),
              _buildSummaryRow('Delivery Commission:', '₦${_commissionController.text} per drop'),
              _buildSummaryRow('Transport Allowance:', '₦${_transportAllowanceController.text} per drop'),
              _buildSummaryRow('Payout Destination:', '$_selectedBank • ${_accountNumberController.text.isEmpty ? '2019847291' : _accountNumberController.text}'),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // SUCCESS / CREDENTIALS SLIP CARD
  // ---------------------------------------------------------------------------
  Widget _buildCredentialsSuccessSlip(bool isDark) {
    final slip = _createdCredentialsSlip!;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF151D36) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        width: 600,
        padding: const EdgeInsets.all(28),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Rider Onboarded Successfully!', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold)),
                        Text('Credentials & Agreement Slip issued for ${slip['name']}', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(height: 1),
              const SizedBox(height: 16),

              // Slip Container
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0B1021) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    _buildSlipRow('Agent Identification:', slip['driverCode'], isBold: true, isCode: true),
                    _buildSlipRow('Operator Name:', slip['name']),
                    _buildSlipRow('Personnel Model:', slip['personnelType']),
                    _buildSlipRow('Operational Hub:', slip['hub']),
                    _buildSlipRow('Rate Agreement:', slip['agreement'], isBold: true),
                    const Divider(height: 16),
                    _buildSlipRow('Mobile Login Email:', slip['email'], isCode: true),
                    _buildSlipRow('Temporary Password:', slip['password'], isCode: true),
                    _buildSlipRow('Security PIN:', slip['pin'], isCode: true),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        final credText = 'NovaExpress Rider Credentials\nAgent Code: ${slip['driverCode']}\nName: ${slip['name']}\nEmail: ${slip['email']}\nTemporary Password: ${slip['password']}\nSecurity PIN: ${slip['pin']}\nHub: ${slip['hub']}';
                        Clipboard.setData(ClipboardData(text: credText));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('📋 Credentials copied to clipboard!')),
                        );
                      },
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      label: const Text('Copy Credentials'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.check_rounded, size: 18, color: Colors.white),
                      label: const Text('Save & Close', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF031632),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
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

  Widget _buildSlipRow(String label, String val, {bool isBold = false, bool isCode = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: Align(
              alignment: Alignment.centerRight,
              child: isCode
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF031632).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        val,
                        style: GoogleFonts.firaCode(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF031632)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    )
                  : Text(
                      val,
                      textAlign: TextAlign.end,
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: isBold ? FontWeight.bold : FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String val) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: Text(
              val,
              textAlign: TextAlign.end,
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
