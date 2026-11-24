import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/nigeria_locations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../dc_console/domain/entities/distribution_center.dart';
import '../../domain/entities/registration_lookups.dart';
import '../../domain/entities/user.dart';
import '../providers/auth_provider.dart';
import '../widgets/registration_role_catalog.dart';
import '../widgets/registration_step_sections.dart';

class RegistrationPage extends ConsumerStatefulWidget {
  final RegistrationAccountType initialRole;
  final void Function(UserEntity createdUser)? onRegistrationSuccess;

  const RegistrationPage({
    super.key,
    this.initialRole = RegistrationAccountType.closer,
    this.onRegistrationSuccess,
  });

  @override
  ConsumerState<RegistrationPage> createState() => _RegistrationPageState();
}

class _RegistrationPageState extends ConsumerState<RegistrationPage> {
  final _stepFormKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();

  late RegistrationAccountType _selectedRole;
  RegistrationRoleTrack? _trackFilter;
  int _currentStep = 0;

  // Lookup Data
  List<RegistrationMerchantOption> _merchants = const [];
  bool _loadingMerchants = false;
  String? _merchantsError;

  List<DistributionCenter> _dcs = const [];
  bool _loadingDcs = false;
  String? _dcsError;

  List<RegistrationSupervisorOption> _supervisors = const [];
  bool _loadingSupervisors = false;

  // Selected Relations
  String? _selectedClientId;
  String? _selectedClientName;
  String? _selectedSupervisorId;
  String? _selectedSupervisorName;

  String? _selectedDcId;
  String? _selectedDcName;
  String? _selectedDcState;
  String? _selectedDcCity;

  // Step 2: Merchant Staff & Marketer Controllers/Options
  final _callTargetController = TextEditingController(text: '50');
  final _adBudgetController = TextEditingController(text: '25000');
  String _commissionModel = 'per_form_submission';
  final _staffCodeController = TextEditingController();

  // Step 2: Merchant Accountant Permissions
  bool _canApproveSettlements = true;
  bool _canManageExpenses = true;
  bool _canDisbursePayouts = true;

  // Step 2: New Merchant (Client) Brand Profile
  final _companyNameController = TextEditingController();
  final _clientCodeController = TextEditingController();
  final _addressController = TextEditingController();
  String _merchantTier = 'standard_merchant';
  String _merchantState = 'FCT - Abuja';
  String _merchantCity = 'Wuse 2';

  // Step 2: DC Staff & Fleet
  final _assignedZoneController = TextEditingController();
  String _personnelType = 'pda';
  String? _riderZone;
  String _vehicleType = registrationVehicleTypes.first;
  final _vehiclePlateController = TextEditingController();

  // Step 3: Identity & Access
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;

  Timer? _emailDebounce;
  bool _checkingEmail = false;
  bool? _emailAvailable;

  Timer? _phoneDebounce;
  bool _checkingPhone = false;
  bool? _phoneAvailable;

  // Step 4: Compensation & Settlement Bank
  String _compensationType = 'commission';
  String? _selectedBankName;
  final _bankAccountNoController = TextEditingController();
  final _bankAccountNameController = TextEditingController();

  // Submission State
  bool _isSubmitting = false;
  String? _submitError;
  UserEntity? _completedUser;

  @override
  void initState() {
    super.initState();
    _selectedRole = widget.initialRole;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadLookups();
    });
  }

  @override
  void dispose() {
    _emailDebounce?.cancel();
    _phoneDebounce?.cancel();
    _scrollController.dispose();
    _callTargetController.dispose();
    _adBudgetController.dispose();
    _staffCodeController.dispose();
    _companyNameController.dispose();
    _clientCodeController.dispose();
    _addressController.dispose();
    _assignedZoneController.dispose();
    _vehiclePlateController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _bankAccountNoController.dispose();
    _bankAccountNameController.dispose();
    super.dispose();
  }

  Future<void> _loadLookups() async {
    await Future.wait([
      _fetchMerchants(),
      _fetchDistributionCenters(),
    ]);
  }

  Future<void> _fetchMerchants() async {
    if (!mounted) return;
    setState(() {
      _loadingMerchants = true;
      _merchantsError = null;
    });
    try {
      final list =
          await ref.read(authProvider.notifier).fetchRegistrationMerchants();
      if (!mounted) return;
      setState(() {
        _merchants = list;
        _loadingMerchants = false;
        if (_selectedClientId != null &&
            !list.any((m) => m.id == _selectedClientId)) {
          _selectedClientId = null;
          _selectedClientName = null;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingMerchants = false;
        _merchantsError = 'Could not load merchants: $e';
      });
    }
  }

  Future<void> _fetchDistributionCenters() async {
    if (!mounted) return;
    setState(() {
      _loadingDcs = true;
      _dcsError = null;
    });
    try {
      final list = await ref
          .read(authProvider.notifier)
          .fetchRegistrationDistributionCenters();
      if (!mounted) return;
      setState(() {
        _dcs = list;
        _loadingDcs = false;
        if (_selectedDcId != null && !list.any((d) => d.id == _selectedDcId)) {
          _selectedDcId = null;
          _selectedDcName = null;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingDcs = false;
        _dcsError = 'Could not load Distribution Centers: $e';
      });
    }
  }

  Future<void> _fetchSupervisorsForMerchant(String clientId) async {
    final needsSup = _selectedRole == RegistrationAccountType.closer ||
        _selectedRole == RegistrationAccountType.marketer;
    if (!needsSup || clientId.isEmpty) {
      if (mounted) {
        setState(() {
          _supervisors = const [];
          _loadingSupervisors = false;
          _selectedSupervisorId = null;
          _selectedSupervisorName = null;
        });
      }
      return;
    }

    if (!mounted) return;
    setState(() {
      _loadingSupervisors = true;
      _supervisors = const [];
      _selectedSupervisorId = null;
      _selectedSupervisorName = null;
    });
    try {
      final isMarketer = _selectedRole == RegistrationAccountType.marketer;
      final list = await ref
          .read(authProvider.notifier)
          .fetchMerchantSupervisors(clientId, isMarketer: isMarketer);
      if (!mounted) return;
      setState(() {
        _supervisors = list;
        _loadingSupervisors = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _supervisors = const [];
        _loadingSupervisors = false;
      });
    }
  }

  void _onRoleSelected(RegistrationAccountType nextRole) {
    if (_selectedRole == nextRole) return;
    setState(() {
      _selectedRole = nextRole;
      _currentStep = 0;
      _submitError = null;
      _selectedSupervisorId = null;
      _selectedSupervisorName = null;
      _staffCodeController.clear();
      _assignedZoneController.clear();
      if (nextRole != RegistrationAccountType.deliveryAgent) {
        _selectedBankName = null;
      } else {
        _selectedBankName ??= registrationNigerianBanks.first;
      }
    });
    if (_selectedClientId != null &&
        (nextRole == RegistrationAccountType.closer ||
            nextRole == RegistrationAccountType.marketer)) {
      _fetchSupervisorsForMerchant(_selectedClientId!);
    }
  }

  void _onMerchantChanged(RegistrationMerchantOption? option) {
    setState(() {
      _selectedClientId = option?.id;
      _selectedClientName = option?.name;
      _selectedSupervisorId = null;
      _selectedSupervisorName = null;
      _submitError = null;
    });
    if (option != null) {
      _fetchSupervisorsForMerchant(option.id);
    }
  }

  void _onDcChanged(DistributionCenter? dc) {
    setState(() {
      _selectedDcId = dc?.id;
      _selectedDcName = dc?.name;
      _selectedDcState = dc?.state;
      _selectedDcCity = dc?.city;
      _submitError = null;

      if (dc != null) {
        final dcZones = dc.operatingZones
            .where((z) => !z.startsWith('STATE:') && z.trim().isNotEmpty)
            .toList();
        _riderZone = dcZones.isNotEmpty
            ? dcZones.first
            : NigeriaLocations.getCitiesForState(dc.state).first;
      } else {
        _riderZone = null;
      }
    });
  }

  void _onEmailChanged(String value) {
    _emailDebounce?.cancel();
    final clean = value.trim();
    final validFormat = RegExp(
      r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$',
    ).hasMatch(clean);

    setState(() {
      _emailAvailable = null;
      _checkingEmail = validFormat;
      _submitError = null;
    });

    if (!validFormat) return;
    _emailDebounce = Timer(const Duration(milliseconds: 350), () async {
      try {
        final exists = await ref
            .read(authProvider.notifier)
            .checkRegistrationEmailExists(clean);
        if (!mounted || _emailController.text.trim() != clean) return;
        setState(() {
          _checkingEmail = false;
          _emailAvailable = !exists;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _checkingEmail = false;
          _emailAvailable = null;
        });
      }
    });
  }

  void _onPhoneChanged(String value) {
    _phoneDebounce?.cancel();
    final clean = value.trim();
    final digits = clean.replaceAll(RegExp(r'[^0-9]'), '');
    final validFormat = digits.length >= 10 && digits.length <= 14;

    setState(() {
      _phoneAvailable = null;
      _checkingPhone = validFormat;
      _submitError = null;
    });

    if (!validFormat) return;
    _phoneDebounce = Timer(const Duration(milliseconds: 350), () async {
      try {
        final exists = await ref
            .read(authProvider.notifier)
            .checkRegistrationPhoneExists(clean);
        if (!mounted || _phoneController.text.trim() != clean) return;
        setState(() {
          _checkingPhone = false;
          _phoneAvailable = !exists;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _checkingPhone = false;
          _phoneAvailable = null;
        });
      }
    });
  }

  void _scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    }
  }

  void _goBackStep() {
    if (_currentStep == 0) return;
    setState(() {
      _currentStep -= 1;
      _submitError = null;
    });
    _scrollToTop();
  }

  Future<void> _onPrimaryAction() async {
    setState(() => _submitError = null);

    final steps = _selectedRole.steps;
    final currentKind = steps[_currentStep];

    if (currentKind != RegistrationStepKind.accountType) {
      final isValid = _stepFormKey.currentState?.validate() ?? false;
      if (!isValid) return;

      if (currentKind == RegistrationStepKind.merchantAccountantSetup &&
          !_canApproveSettlements &&
          !_canManageExpenses &&
          !_canDisbursePayouts) {
        setState(() {
          _submitError =
              'Select at least one finance permission scope for Merchant Accountant.';
        });
        return;
      }
    }

    if (currentKind == RegistrationStepKind.merchantAssignment ||
        currentKind == RegistrationStepKind.merchantAccountantSetup) {
      if (_selectedClientId == null || _selectedClientId!.isEmpty) {
        setState(() => _submitError = 'Please select your Partner Merchant.');
        return;
      }
    }

    if (currentKind == RegistrationStepKind.dcHubAssignment ||
        currentKind == RegistrationStepKind.fleetAndVehicle) {
      if (_selectedDcId == null || _selectedDcId!.isEmpty) {
        setState(() =>
            _submitError = 'Please select an assigned Distribution Center.');
        return;
      }
    }

    final isLastStep = _currentStep >= steps.length - 1;
    if (!isLastStep) {
      setState(() {
        _currentStep += 1;
        if (_selectedRole == RegistrationAccountType.deliveryAgent &&
            steps[_currentStep] ==
                RegistrationStepKind.riderCompensationBankAndReview) {
          _selectedBankName ??= registrationNigerianBanks.first;
        }
      });
      if (_selectedRole.requiresMerchant && _merchants.isEmpty) {
        _fetchMerchants();
      }
      if (_selectedRole.requiresDistributionCenter && _dcs.isEmpty) {
        _fetchDistributionCenters();
      }
      _scrollToTop();
      return;
    }

    await _submitRegistration();
  }

  OpenRegistrationRequest _buildRequest() {
    final isRider = _selectedRole == RegistrationAccountType.deliveryAgent;
    final isPda = _personnelType == 'pda';
    final effectiveComp = isPda ? 'commission' : _compensationType;

    double commRate = 1000.0;
    double transp = 1500.0;
    double fuel = 0.0;
    double failed = 500.0;
    double salary = 0.0;

    if (isRider) {
      if (isPda) {
        commRate = 1000.0;
        transp = 1500.0;
        fuel = 0.0;
        failed = 500.0;
        salary = 0.0;
      } else {
        transp = 0.0;
        fuel = 800.0;
        failed = 300.0;
        switch (effectiveComp) {
          case 'salary':
            commRate = 0.0;
            salary = 120000.0;
            break;
          case 'hybrid':
            commRate = 500.0;
            salary = 85000.0;
            break;
          default:
            commRate = 500.0;
            salary = 0.0;
        }
      }
    }

    final adBudget = double.tryParse(
          _adBudgetController.text.replaceAll(',', '').trim(),
        ) ??
        25000.0;
    final callTarget = int.tryParse(_callTargetController.text.trim()) ?? 50;

    final resolvedZone = isRider
        ? (_riderZone ?? _selectedDcCity ?? 'Central Hub')
        : _assignedZoneController.text.trim();

    final bankName = isRider
        ? (_selectedBankName ?? registrationNigerianBanks.first)
        : (_selectedBankName ?? '');

    return OpenRegistrationRequest(
      accountType: _selectedRole,
      firstName: _firstNameController.text.trim(),
      lastName: _lastNameController.text.trim(),
      email: _emailController.text.trim().toLowerCase(),
      phone: _phoneController.text.trim(),
      password: _passwordController.text,
      clientId: _selectedClientId,
      clientCompanyName: _selectedClientName,
      supervisorId: _selectedSupervisorId,
      supervisorName: _selectedSupervisorName,
      dailyCallTarget: callTarget,
      dailyAdSpendBudget: adBudget,
      commissionModel: _commissionModel,
      canApproveSettlements: _canApproveSettlements,
      canManageExpenses: _canManageExpenses,
      canDisbursePayouts: _canDisbursePayouts,
      companyName: _companyNameController.text.trim(),
      clientCode: _clientCodeController.text.trim(),
      merchantTier: _merchantTier,
      closerLimit: _merchantTier == 'enterprise' ? 250 : 0,
      address: _addressController.text.trim(),
      city: _merchantCity,
      stateName: _merchantState,
      distributionCenterId: _selectedDcId,
      distributionCenterName: _selectedDcName,
      assignedZone: resolvedZone,
      staffCode: _staffCodeController.text.trim(),
      operatingState: _selectedDcState,
      operatingCity: _selectedDcCity,
      personnelType: _personnelType,
      compensationType: effectiveComp,
      commissionRate: commRate,
      transportAllowance: transp,
      fuelAllowance: fuel,
      failedDeliveryAllowance: failed,
      baseSalary: salary,
      vehicleType: _vehicleType,
      vehiclePlateNumber: _vehiclePlateController.text.trim().toUpperCase(),
      bankName: bankName,
      bankAccountNumber: _bankAccountNoController.text.trim(),
      bankAccountName: _bankAccountNameController.text.trim(),
    );
  }

  Future<void> _submitRegistration() async {
    setState(() {
      _isSubmitting = true;
      _submitError = null;
    });

    try {
      final req = _buildRequest();
      final createdUser = await ref
          .read(authProvider.notifier)
          .completeOpenRegistration(req, autoSignIn: true);

      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _completedUser = createdUser;
      });

      widget.onRegistrationSuccess?.call(createdUser);

      final router = GoRouter.maybeOf(context);
      if (router != null) {
        router.go(createdUser.homeConsoleRoute);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _submitError = e.toString().replaceFirst('Exception: ', '');
      });
      _scrollToTop();
    }
  }

  void _navigateToLogin() {
    final router = GoRouter.maybeOf(context);
    if (router != null) {
      router.go('/login');
    } else {
      Navigator.of(context).maybePop();
    }
  }

  Widget _buildSummaryCard() {
    final fullName =
        '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}'
            .trim();
    final selectedDc = _dcs.where((d) => d.id == _selectedDcId).firstOrNull;
    final zoneLabel = _selectedRole == RegistrationAccountType.deliveryAgent
        ? _riderZone
        : _assignedZoneController.text.trim();
    final bankAcc = _bankAccountNoController.text.trim();
    final bankSummary =
        (_selectedBankName != null && _selectedBankName!.isNotEmpty && bankAcc.isNotEmpty)
            ? '${_selectedBankName!} • $bankAcc'
            : null;

    return RegistrationFinalSummaryCard(
      role: _selectedRole,
      fullName: fullName,
      email: _emailController.text.trim(),
      phone: _phoneController.text.trim(),
      partnerMerchantLabel: _selectedRole.requiresMerchant
          ? _selectedClientName
          : null,
      merchantBrandLabel: _selectedRole == RegistrationAccountType.client
          ? '${_companyNameController.text.trim()} ($_merchantCity, $_merchantState)'
          : null,
      dcLabel: _selectedRole.requiresDistributionCenter
          ? (selectedDc != null
              ? '${selectedDc.name} (${selectedDc.code})'
              : _selectedDcName)
          : null,
      zoneOrDeskLabel:
          (zoneLabel != null && zoneLabel.isNotEmpty) ? zoneLabel : null,
      vehicleLabel: _selectedRole == RegistrationAccountType.deliveryAgent
          ? '$_vehicleType • ${_vehiclePlateController.text.trim().toUpperCase()}'
          : null,
      bankSummaryLabel: bankSummary,
    );
  }

  Widget _buildActiveStepBody() {
    final steps = _selectedRole.steps;
    final currentKind = steps[_currentStep];
    final summary = _buildSummaryCard();

    switch (currentKind) {
      case RegistrationStepKind.accountType:
        return RegistrationRoleSelectionStep(
          selectedRole: _selectedRole,
          selectedTrackFilter: _trackFilter,
          onTrackFilterChanged: (t) => setState(() => _trackFilter = t),
          onRoleSelected: _onRoleSelected,
        );

      case RegistrationStepKind.merchantAssignment:
        return MerchantAssignmentStep(
          role: _selectedRole,
          merchants: _merchants,
          loadingMerchants: _loadingMerchants,
          merchantsError: _merchantsError,
          onRetryMerchants: _fetchMerchants,
          selectedClientId: _selectedClientId,
          onMerchantChanged: _onMerchantChanged,
          supervisors: _supervisors,
          loadingSupervisors: _loadingSupervisors,
          selectedSupervisorId: _selectedSupervisorId,
          onSupervisorChanged: (supId) {
            final matched = _supervisors.where((s) => s.id == supId).firstOrNull;
            setState(() {
              _selectedSupervisorId = supId;
              _selectedSupervisorName = matched?.fullName;
            });
          },
          callTargetController: _callTargetController,
          adBudgetController: _adBudgetController,
          commissionModel: _commissionModel,
          onCommissionModelChanged: (m) => setState(() => _commissionModel = m),
          staffCodeController: _staffCodeController,
        );

      case RegistrationStepKind.merchantAccountantSetup:
        return MerchantAccountantSetupStep(
          role: _selectedRole,
          merchants: _merchants,
          loadingMerchants: _loadingMerchants,
          merchantsError: _merchantsError,
          onRetryMerchants: _fetchMerchants,
          selectedClientId: _selectedClientId,
          onMerchantChanged: _onMerchantChanged,
          staffCodeController: _staffCodeController,
          canApproveSettlements: _canApproveSettlements,
          canManageExpenses: _canManageExpenses,
          canDisbursePayouts: _canDisbursePayouts,
          onCanApproveChanged: (v) =>
              setState(() => _canApproveSettlements = v),
          onCanExpensesChanged: (v) => setState(() => _canManageExpenses = v),
          onCanDisburseChanged: (v) => setState(() => _canDisbursePayouts = v),
        );

      case RegistrationStepKind.merchantBusinessProfile:
        return MerchantBusinessProfileStep(
          companyNameController: _companyNameController,
          clientCodeController: _clientCodeController,
          addressController: _addressController,
          merchantTier: _merchantTier,
          onTierChanged: (t) => setState(() => _merchantTier = t),
          selectedState: _merchantState,
          onStateChanged: (nextState) {
            final cities = NigeriaLocations.getCitiesForState(nextState);
            setState(() {
              _merchantState = nextState;
              _merchantCity =
                  cities.isNotEmpty ? cities.first : 'Wuse 2';
            });
          },
          selectedCity: _merchantCity,
          onCityChanged: (c) => setState(() => _merchantCity = c),
        );

      case RegistrationStepKind.dcHubAssignment:
        return DcHubAssignmentStep(
          role: _selectedRole,
          dcs: _dcs,
          loadingDcs: _loadingDcs,
          dcsError: _dcsError,
          onRetryDcs: _fetchDistributionCenters,
          selectedDcId: _selectedDcId,
          onDcChanged: _onDcChanged,
          assignedZoneController: _assignedZoneController,
          staffCodeController: _staffCodeController,
        );

      case RegistrationStepKind.fleetAndVehicle:
        return FleetAndVehicleStep(
          role: _selectedRole,
          dcs: _dcs,
          loadingDcs: _loadingDcs,
          dcsError: _dcsError,
          onRetryDcs: _fetchDistributionCenters,
          selectedDcId: _selectedDcId,
          onDcChanged: _onDcChanged,
          personnelType: _personnelType,
          onPersonnelTypeChanged: (p) => setState(() {
            _personnelType = p;
            if (p == 'pda') {
              _compensationType = 'commission';
            }
          }),
          selectedZone: _riderZone,
          onZoneChanged: (z) => setState(() => _riderZone = z),
          vehicleType: _vehicleType,
          onVehicleTypeChanged: (v) => setState(() => _vehicleType = v),
          vehiclePlateController: _vehiclePlateController,
        );

      case RegistrationStepKind.identityCredentials:
        return IdentityCredentialsStep(
          role: _selectedRole,
          firstNameController: _firstNameController,
          lastNameController: _lastNameController,
          emailController: _emailController,
          phoneController: _phoneController,
          passwordController: _passwordController,
          confirmPasswordController: _confirmPasswordController,
          obscurePassword: _obscurePassword,
          onToggleObscurePassword: () =>
              setState(() => _obscurePassword = !_obscurePassword),
          emailAvailable: _emailAvailable,
          checkingEmail: _checkingEmail,
          onEmailChanged: _onEmailChanged,
          phoneAvailable: _phoneAvailable,
          checkingPhone: _checkingPhone,
          onPhoneChanged: _onPhoneChanged,
          finalSummaryWidget: steps.length == 3 ? summary : null,
        );

      case RegistrationStepKind.payoutBankAndReview:
        return PayoutBankAndReviewStep(
          role: _selectedRole,
          selectedBankName: _selectedBankName,
          onBankChanged: (b) => setState(() => _selectedBankName = b),
          bankAccountNoController: _bankAccountNoController,
          bankAccountNameController: _bankAccountNameController,
          finalSummaryWidget: summary,
        );

      case RegistrationStepKind.riderCompensationBankAndReview:
        return RiderCompensationBankAndReviewStep(
          personnelType: _personnelType,
          compensationType: _compensationType,
          onCompensationTypeChanged: (c) =>
              setState(() => _compensationType = c),
          selectedBankName: _selectedBankName,
          onBankChanged: (b) => setState(() => _selectedBankName = b),
          bankAccountNoController: _bankAccountNoController,
          bankAccountNameController: _bankAccountNameController,
          finalSummaryWidget: summary,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 480;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final steps = _selectedRole.steps;
    final isLastStep = _currentStep >= steps.length - 1;
    final visuals = RegistrationRoleVisuals.of(_selectedRole);

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          Positioned(
            top: -120,
            right: -100,
            child: Container(
              width: 360,
              height: 360,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    visuals.color.withValues(alpha: isDark ? 0.18 : 0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: EdgeInsets.symmetric(
                  horizontal: isCompact ? 12 : 24,
                  vertical: isCompact ? 14 : 24,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Top Header Bar
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: const Color(0xFF006C4C)
                                        .withValues(alpha: 0.25),
                                  ),
                                ),
                                child: ClipOval(
                                  child: Image.asset(
                                    'assets/images/square_logo.png',
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Icon(
                                      Icons.local_shipping_rounded,
                                      size: 20,
                                      color: Color(0xFF006C4C),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Flexible(
                                fit: FlexFit.loose,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'NovaXpress Onboarding',
                                      style: GoogleFonts.inter(
                                        fontSize: isCompact ? 16 : 18,
                                        fontWeight: FontWeight.w900,
                                        color: isDark
                                            ? Colors.white
                                            : const Color(0xFF0F172A),
                                      ),
                                    ),
                                    Text(
                                      'Open Multi-Role Account Registration',
                                      style: GoogleFonts.inter(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                        color: isDark
                                            ? const Color(0xFF94A3B8)
                                            : const Color(0xFF475569),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          TextButton.icon(
                            key: const Key('reg_back_to_login_top'),
                            onPressed: _isSubmitting ? null : _navigateToLogin,
                            icon: const Icon(Icons.login_rounded, size: 17),
                            label: const Text('Sign In Instead'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Main Wizard Card
                      Container(
                        padding: EdgeInsets.all(isCompact ? 16 : 26),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.surfaceDark
                              : Colors.white,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: isDark
                                ? AppColors.borderDark
                                : const Color(0xFFE2E8F0),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(
                                alpha: isDark ? 0.35 : 0.05,
                              ),
                              blurRadius: 22,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            RegistrationStepHeader(
                              role: _selectedRole,
                              currentStepIndex: _currentStep,
                              onStepTapped: (targetStep) {
                                if (targetStep < _currentStep &&
                                    !_isSubmitting) {
                                  setState(() {
                                    _currentStep = targetStep;
                                    _submitError = null;
                                  });
                                }
                              },
                            ),
                            const SizedBox(height: 18),
                            const Divider(height: 1),
                            const SizedBox(height: 18),

                            if (_submitError != null) ...[
                              Container(
                                key: const Key('reg_error_banner'),
                                padding: const EdgeInsets.all(12),
                                margin: const EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(
                                  color:
                                      AppColors.danger.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color:
                                        AppColors.danger.withValues(alpha: 0.35),
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(
                                      Icons.error_outline_rounded,
                                      color: AppColors.danger,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _submitError!,
                                        style: GoogleFonts.inter(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.danger,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            if (_completedUser != null) ...[
                              Container(
                                key: const Key('reg_success_banner'),
                                padding: const EdgeInsets.all(14),
                                margin: const EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF16A34A)
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0xFF16A34A)
                                        .withValues(alpha: 0.35),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.check_circle_rounded,
                                      color: Color(0xFF16A34A),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'Welcome ${_completedUser!.fullName}! Account created for ${_completedUser!.roleDescription}. Launching ${_selectedRole.targetConsoleLabel}...',
                                        style: GoogleFonts.inter(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w700,
                                          color: isDark
                                              ? const Color(0xFF86EFAC)
                                              : const Color(0xFF166534),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            Form(
                              key: _stepFormKey,
                              child: KeyedSubtree(
                                key: ValueKey(
                                  '${_selectedRole.roleKey}_step_$_currentStep',
                                ),
                                child: _buildActiveStepBody(),
                              ),
                            ),

                            const SizedBox(height: 22),

                            // Footer Step Action Buttons
                            Row(
                              children: [
                                if (_currentStep > 0) ...[
                                  OutlinedButton.icon(
                                    key: const Key('reg_back_btn'),
                                    style: OutlinedButton.styleFrom(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: isCompact ? 12 : 18,
                                        vertical: 14,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    onPressed: _isSubmitting ? null : _goBackStep,
                                    icon: const Icon(
                                      Icons.arrow_back_rounded,
                                      size: 18,
                                    ),
                                    label: const Text('Back'),
                                  ),
                                  const SizedBox(width: 10),
                                ],
                                Expanded(
                                  child: SizedBox(
                                    height: 50,
                                    child: ElevatedButton(
                                      key: const Key('reg_next_or_submit_btn'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: isLastStep
                                            ? AppColors.orange
                                            : (isDark
                                                ? AppColors.orange
                                                : const Color(0xFF0F172A)),
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                      ),
                                      onPressed: _isSubmitting
                                          ? null
                                          : _onPrimaryAction,
                                      child: _isSubmitting
                                          ? const SizedBox(
                                              width: 22,
                                              height: 22,
                                              child: CircularProgressIndicator(
                                                color: Colors.white,
                                                strokeWidth: 2.2,
                                              ),
                                            )
                                          : FittedBox(
                                              fit: BoxFit.scaleDown,
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Text(
                                                    isLastStep
                                                        ? 'Create Account & Launch Console'
                                                        : 'Continue to ${_selectedRole.stepShortTitle(steps[_currentStep + 1])}',
                                                    style: GoogleFonts.inter(
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Icon(
                                                    isLastStep
                                                        ? Icons
                                                            .rocket_launch_rounded
                                                        : Icons
                                                            .arrow_forward_rounded,
                                                    size: 18,
                                                  ),
                                                ],
                                              ),
                                            ),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 16),
                            Wrap(
                              alignment: WrapAlignment.center,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 4,
                              children: [
                                Text(
                                  'Already have a NovaXpress account?',
                                  style: GoogleFonts.inter(
                                    fontSize: 12.5,
                                    color: isDark
                                        ? const Color(0xFF94A3B8)
                                        : const Color(0xFF64748B),
                                  ),
                                ),
                                InkWell(
                                  onTap: _isSubmitting ? null : _navigateToLogin,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 2,
                                    ),
                                    child: Text(
                                      'Sign In',
                                      style: GoogleFonts.inter(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w800,
                                        color: isDark
                                            ? AppColors.orange
                                            : AppColors.navy,
                                      ),
                                    ),
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
              ),
            ),
          ),
        ],
      ),
    );
  }
}

