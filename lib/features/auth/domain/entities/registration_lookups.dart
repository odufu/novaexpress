const List<String> registrationNigerianBanks = [
  'Guaranty Trust Bank (GTBank)',
  'Access Bank',
  'First Bank of Nigeria',
  'Zenith Bank',
  'United Bank for Africa (UBA)',
  'Kuda Microfinance Bank',
  'Moniepoint Microfinance Bank',
  'OPay Digital Services',
  'Stanbic IBTC Bank',
  'Fidelity Bank',
  'First City Monument Bank (FCMB)',
  'Sterling Bank',
  'Union Bank of Nigeria',
  'Wema Bank / ALAT',
  'Palmpay',
];

const List<String> registrationVehicleTypes = [
  'Motorcycle (Bajaj Boxer)',
  'Motorcycle (TVS HLX / Max)',
  'Electric Motorcycle',
  'Delivery Van / Mini Van',
  'Bicycle / E-Bike',
  'Sedan / Car',
];

enum RegistrationRoleTrack {
  merchantsAndGrowth,
  hubAndFinance,
  deliveryFleet,
}

extension RegistrationRoleTrackX on RegistrationRoleTrack {
  String get label {
    switch (this) {
      case RegistrationRoleTrack.merchantsAndGrowth:
        return 'Merchants & Growth';
      case RegistrationRoleTrack.hubAndFinance:
        return 'DC Hub & Finance';
      case RegistrationRoleTrack.deliveryFleet:
        return 'Delivery Fleet';
    }
  }
}

enum RegistrationStepKind {
  accountType,
  merchantAssignment,
  merchantAccountantSetup,
  merchantBusinessProfile,
  dcHubAssignment,
  fleetAndVehicle,
  identityCredentials,
  payoutBankAndReview,
  riderCompensationBankAndReview,
}

enum RegistrationAccountType {
  closer,
  salesSupervisor,
  marketer,
  marketingSupervisor,
  merchantAccountant,
  client,
  dcOperations,
  dcStockAdmin,
  dcFinanceAdmin,
  dcManager,
  generalAccountant,
  deliveryAgent,
}

extension RegistrationAccountTypeX on RegistrationAccountType {
  String get roleKey {
    switch (this) {
      case RegistrationAccountType.closer:
        return 'closer';
      case RegistrationAccountType.salesSupervisor:
        return 'sales_supervisor';
      case RegistrationAccountType.marketer:
        return 'marketer';
      case RegistrationAccountType.marketingSupervisor:
        return 'marketing_supervisor';
      case RegistrationAccountType.merchantAccountant:
        return 'merchant_accountant';
      case RegistrationAccountType.client:
        return 'client';
      case RegistrationAccountType.dcOperations:
        return 'dc_operations';
      case RegistrationAccountType.dcStockAdmin:
        return 'dc_stock_admin';
      case RegistrationAccountType.dcFinanceAdmin:
        return 'dc_finance_admin';
      case RegistrationAccountType.dcManager:
        return 'dc_manager';
      case RegistrationAccountType.generalAccountant:
        return 'general_accountant';
      case RegistrationAccountType.deliveryAgent:
        return 'delivery_agent';
    }
  }

  RegistrationRoleTrack get track {
    switch (this) {
      case RegistrationAccountType.closer:
      case RegistrationAccountType.salesSupervisor:
      case RegistrationAccountType.marketer:
      case RegistrationAccountType.marketingSupervisor:
      case RegistrationAccountType.merchantAccountant:
      case RegistrationAccountType.client:
        return RegistrationRoleTrack.merchantsAndGrowth;
      case RegistrationAccountType.dcOperations:
      case RegistrationAccountType.dcStockAdmin:
      case RegistrationAccountType.dcFinanceAdmin:
      case RegistrationAccountType.dcManager:
      case RegistrationAccountType.generalAccountant:
        return RegistrationRoleTrack.hubAndFinance;
      case RegistrationAccountType.deliveryAgent:
        return RegistrationRoleTrack.deliveryFleet;
    }
  }

  String get title {
    switch (this) {
      case RegistrationAccountType.closer:
        return 'Telesales Closer';
      case RegistrationAccountType.salesSupervisor:
        return 'Sales Rep Supervisor';
      case RegistrationAccountType.marketer:
        return 'Digital Marketer';
      case RegistrationAccountType.marketingSupervisor:
        return 'Marketing Supervisor';
      case RegistrationAccountType.merchantAccountant:
        return 'Merchant Accountant';
      case RegistrationAccountType.client:
        return 'E-Commerce Merchant';
      case RegistrationAccountType.dcOperations:
        return 'DC Dispatch & Orders Officer';
      case RegistrationAccountType.dcStockAdmin:
        return 'DC Stock & Inventory Officer';
      case RegistrationAccountType.dcFinanceAdmin:
        return 'DC Finance & Remittance Officer';
      case RegistrationAccountType.dcManager:
        return 'DC Operations Supervisor';
      case RegistrationAccountType.generalAccountant:
        return 'National General Accountant';
      case RegistrationAccountType.deliveryAgent:
        return 'Field Delivery Agent (Rider)';
    }
  }

  String get badge {
    switch (this) {
      case RegistrationAccountType.closer:
        return 'CLOSER';
      case RegistrationAccountType.salesSupervisor:
        return 'SALES SUP';
      case RegistrationAccountType.marketer:
        return 'MARKETER';
      case RegistrationAccountType.marketingSupervisor:
        return 'MKT SUP';
      case RegistrationAccountType.merchantAccountant:
        return 'MCH ACC';
      case RegistrationAccountType.client:
        return 'MERCHANT';
      case RegistrationAccountType.dcOperations:
        return 'DISPATCH OPS';
      case RegistrationAccountType.dcStockAdmin:
        return 'STOCK OPS';
      case RegistrationAccountType.dcFinanceAdmin:
        return 'FINANCE OPS';
      case RegistrationAccountType.dcManager:
        return 'DC MANAGER';
      case RegistrationAccountType.generalAccountant:
        return 'NATL ACC';
      case RegistrationAccountType.deliveryAgent:
        return 'RIDER / PDA';
    }
  }

  String get subtitle {
    switch (this) {
      case RegistrationAccountType.closer:
        return 'Confirm merchant leads, handle calls, and request order upgrades.';
      case RegistrationAccountType.salesSupervisor:
        return 'Oversee a merchant closer team, monitor conversion, and approve UPGs.';
      case RegistrationAccountType.marketer:
        return 'Launch lead forms, manage Meta Pixel/CAPI tracking, and scale ad ROI.';
      case RegistrationAccountType.marketingSupervisor:
        return 'Lead growth buyers and audit team lead forms and delivery ROI.';
      case RegistrationAccountType.merchantAccountant:
        return 'Reconcile merchant DC COD settlements, operating expenses, and payouts.';
      case RegistrationAccountType.client:
        return 'Onboard your e-commerce brand, products, closers, and DC inventory.';
      case RegistrationAccountType.dcOperations:
        return 'Manage inbound orders, rider dispatch routing, and delivery coordination.';
      case RegistrationAccountType.dcStockAdmin:
        return 'Control DC shelf stock, rider inventory handover, returns, and restocks.';
      case RegistrationAccountType.dcFinanceAdmin:
        return 'Verify rider COD remittances, cash vault logs, and bank settlements.';
      case RegistrationAccountType.dcManager:
        return 'Supervise full Distribution Center operations, fleet, and merchant hubs.';
      case RegistrationAccountType.generalAccountant:
        return 'Audit national treasury, inter-DC transfers, and merchant settlements.';
      case RegistrationAccountType.deliveryAgent:
        return 'Execute last-mile deliveries with company or personal fleet vehicles.';
    }
  }

  String get requirementSummary {
    switch (this) {
      case RegistrationAccountType.closer:
        return 'Requires Partner Merchant & Call Target';
      case RegistrationAccountType.salesSupervisor:
        return 'Requires Partner Merchant & Supervisory Desk';
      case RegistrationAccountType.marketer:
        return 'Requires Partner Merchant & Ad Budget';
      case RegistrationAccountType.marketingSupervisor:
        return 'Requires Partner Merchant & Team Budget';
      case RegistrationAccountType.merchantAccountant:
        return 'Requires Partner Merchant & Finance Permissions';
      case RegistrationAccountType.client:
        return 'Requires Brand Profile & Pickup Address';
      case RegistrationAccountType.dcOperations:
        return 'Requires Distribution Center & Dispatch Sector';
      case RegistrationAccountType.dcStockAdmin:
        return 'Requires Distribution Center & Warehouse Bay';
      case RegistrationAccountType.dcFinanceAdmin:
        return 'Requires Distribution Center & Vault Desk';
      case RegistrationAccountType.dcManager:
        return 'Requires Distribution Center Hub';
      case RegistrationAccountType.generalAccountant:
        return 'Requires Executive Hub & Treasury Division';
      case RegistrationAccountType.deliveryAgent:
        return 'Requires Distribution Center, Vehicle & Payout Bank';
    }
  }

  String get targetConsoleRoute {
    switch (this) {
      case RegistrationAccountType.closer:
        return '/closer';
      case RegistrationAccountType.salesSupervisor:
        return '/sales-supervisor';
      case RegistrationAccountType.marketer:
      case RegistrationAccountType.marketingSupervisor:
        return '/marketer';
      case RegistrationAccountType.merchantAccountant:
        return '/merchant-settlements';
      case RegistrationAccountType.client:
        return '/client';
      case RegistrationAccountType.dcOperations:
        return '/ops';
      case RegistrationAccountType.dcStockAdmin:
        return '/stock-ops';
      case RegistrationAccountType.dcFinanceAdmin:
        return '/finance-ops';
      case RegistrationAccountType.dcManager:
        return '/dc';
      case RegistrationAccountType.generalAccountant:
        return '/accountant';
      case RegistrationAccountType.deliveryAgent:
        return '/';
    }
  }

  String get targetConsoleLabel {
    switch (this) {
      case RegistrationAccountType.closer:
        return 'Closer Telesales Desk';
      case RegistrationAccountType.salesSupervisor:
        return 'Sales Supervisor Console';
      case RegistrationAccountType.marketer:
        return 'Digital Marketer Console';
      case RegistrationAccountType.marketingSupervisor:
        return 'Marketing Supervisor Console';
      case RegistrationAccountType.merchantAccountant:
        return 'Merchant Settlements Portal';
      case RegistrationAccountType.client:
        return 'Merchant Portal';
      case RegistrationAccountType.dcOperations:
        return 'DC Dispatch Ops Portal';
      case RegistrationAccountType.dcStockAdmin:
        return 'Stock Operations Console';
      case RegistrationAccountType.dcFinanceAdmin:
        return 'DC Finance Ops Console';
      case RegistrationAccountType.dcManager:
        return 'DC Command Console';
      case RegistrationAccountType.generalAccountant:
        return 'National Accountant Console';
      case RegistrationAccountType.deliveryAgent:
        return 'Rider Delivery App';
    }
  }

  bool get requiresMerchant =>
      this == RegistrationAccountType.closer ||
      this == RegistrationAccountType.salesSupervisor ||
      this == RegistrationAccountType.marketer ||
      this == RegistrationAccountType.marketingSupervisor ||
      this == RegistrationAccountType.merchantAccountant;

  bool get requiresDistributionCenter =>
      this == RegistrationAccountType.dcOperations ||
      this == RegistrationAccountType.dcStockAdmin ||
      this == RegistrationAccountType.dcFinanceAdmin ||
      this == RegistrationAccountType.dcManager ||
      this == RegistrationAccountType.generalAccountant ||
      this == RegistrationAccountType.deliveryAgent;

  List<RegistrationStepKind> get steps {
    switch (this) {
      case RegistrationAccountType.closer:
      case RegistrationAccountType.salesSupervisor:
      case RegistrationAccountType.marketer:
      case RegistrationAccountType.marketingSupervisor:
        return const [
          RegistrationStepKind.accountType,
          RegistrationStepKind.merchantAssignment,
          RegistrationStepKind.identityCredentials,
          RegistrationStepKind.payoutBankAndReview,
        ];
      case RegistrationAccountType.merchantAccountant:
        return const [
          RegistrationStepKind.accountType,
          RegistrationStepKind.merchantAccountantSetup,
          RegistrationStepKind.identityCredentials,
        ];
      case RegistrationAccountType.client:
        return const [
          RegistrationStepKind.accountType,
          RegistrationStepKind.merchantBusinessProfile,
          RegistrationStepKind.identityCredentials,
          RegistrationStepKind.payoutBankAndReview,
        ];
      case RegistrationAccountType.dcOperations:
      case RegistrationAccountType.dcStockAdmin:
      case RegistrationAccountType.dcFinanceAdmin:
      case RegistrationAccountType.dcManager:
      case RegistrationAccountType.generalAccountant:
        return const [
          RegistrationStepKind.accountType,
          RegistrationStepKind.dcHubAssignment,
          RegistrationStepKind.identityCredentials,
        ];
      case RegistrationAccountType.deliveryAgent:
        return const [
          RegistrationStepKind.accountType,
          RegistrationStepKind.fleetAndVehicle,
          RegistrationStepKind.identityCredentials,
          RegistrationStepKind.riderCompensationBankAndReview,
        ];
    }
  }

  String stepShortTitle(RegistrationStepKind step) {
    switch (step) {
      case RegistrationStepKind.accountType:
        return 'Account Type';
      case RegistrationStepKind.merchantAssignment:
        return (this == RegistrationAccountType.marketer ||
                this == RegistrationAccountType.marketingSupervisor)
            ? 'Merchant & Ads'
            : 'Merchant & Team';
      case RegistrationStepKind.merchantAccountantSetup:
        return 'Merchant & Scope';
      case RegistrationStepKind.merchantBusinessProfile:
        return 'Brand & Address';
      case RegistrationStepKind.dcHubAssignment:
        if (this == RegistrationAccountType.generalAccountant) {
          return 'Treasury Hub';
        }
        if (this == RegistrationAccountType.dcStockAdmin) {
          return 'DC & Inventory';
        }
        if (this == RegistrationAccountType.dcFinanceAdmin) {
          return 'DC & Cash Vault';
        }
        return 'Distribution Center';
      case RegistrationStepKind.fleetAndVehicle:
        return 'DC & Vehicle';
      case RegistrationStepKind.identityCredentials:
        return steps.length == 3 ? 'Profile & Review' : 'Profile & Access';
      case RegistrationStepKind.payoutBankAndReview:
        return 'Bank & Review';
      case RegistrationStepKind.riderCompensationBankAndReview:
        return 'Pay, Bank & Review';
    }
  }

  String stepHeadline(RegistrationStepKind step) {
    switch (step) {
      case RegistrationStepKind.accountType:
        return 'Choose Your Account Type';
      case RegistrationStepKind.merchantAssignment:
        switch (this) {
          case RegistrationAccountType.closer:
            return 'Link Partner Merchant & Call Targets';
          case RegistrationAccountType.salesSupervisor:
            return 'Link Partner Merchant & Supervisory Desk';
          case RegistrationAccountType.marketer:
            return 'Link Partner Merchant & Campaign Scope';
          case RegistrationAccountType.marketingSupervisor:
            return 'Link Partner Merchant & Growth Oversight';
          default:
            return 'Link Partner Merchant';
        }
      case RegistrationStepKind.merchantAccountantSetup:
        return 'Partner Merchant & Finance Permissions';
      case RegistrationStepKind.merchantBusinessProfile:
        return 'Merchant Brand Profile & Pickup Hub';
      case RegistrationStepKind.dcHubAssignment:
        switch (this) {
          case RegistrationAccountType.dcOperations:
            return 'Select Distribution Center & Dispatch Sector';
          case RegistrationAccountType.dcStockAdmin:
            return 'Select Distribution Center & Custody Bay';
          case RegistrationAccountType.dcFinanceAdmin:
            return 'Select Distribution Center & Vault Desk';
          case RegistrationAccountType.dcManager:
            return 'Select Managed Distribution Center';
          case RegistrationAccountType.generalAccountant:
            return 'Select Executive Hub & Audit Division';
          default:
            return 'Select Distribution Center';
        }
      case RegistrationStepKind.fleetAndVehicle:
        return 'Assign Station Hub, Zone & Vehicle';
      case RegistrationStepKind.identityCredentials:
        return steps.length == 3
            ? 'Your Credentials & Final Review'
            : 'Personal Identity & Login Access';
      case RegistrationStepKind.payoutBankAndReview:
        return this == RegistrationAccountType.client
            ? 'COD Remittance Bank & Final Review'
            : 'Commission Settlement Bank & Final Review';
      case RegistrationStepKind.riderCompensationBankAndReview:
        return 'Compensation Plan, Payout Bank & Review';
    }
  }
}

class RegistrationMerchantOption {
  final String id;
  final String name;
  final String code;
  final String city;
  final String state;
  final String tier;
  final bool isEnterprise;

  const RegistrationMerchantOption({
    required this.id,
    required this.name,
    required this.code,
    this.city = '',
    this.state = '',
    this.tier = 'standard_merchant',
    this.isEnterprise = false,
  });

  factory RegistrationMerchantOption.fromJson(Map<String, dynamic> json) {
    final companyName = json['company_name']?.toString().trim();
    final name = json['name']?.toString().trim();
    final resolvedName = (companyName != null && companyName.isNotEmpty)
        ? companyName
        : ((name != null && name.isNotEmpty) ? name : 'Partner Merchant');
    return RegistrationMerchantOption(
      id: json['id']?.toString() ?? '',
      name: resolvedName,
      code: json['code']?.toString() ?? 'CLI-001',
      city: json['city']?.toString() ?? '',
      state: json['state']?.toString() ?? '',
      tier: json['tier']?.toString() ?? 'standard_merchant',
      isEnterprise: json['is_enterprise'] == true,
    );
  }
}

class RegistrationSupervisorOption {
  final String id;
  final String? userId;
  final String code;
  final String fullName;
  final String clientId;
  final bool isMarketer;

  const RegistrationSupervisorOption({
    required this.id,
    this.userId,
    required this.code,
    required this.fullName,
    required this.clientId,
    this.isMarketer = false,
  });
}

class OpenRegistrationRequest {
  final RegistrationAccountType accountType;
  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final String password;

  // Merchant-linked roles (closer, salesSupervisor, marketer, marketingSupervisor, merchantAccountant)
  final String? clientId;
  final String? clientCompanyName;
  final String? supervisorId;
  final String? supervisorName;
  final int dailyCallTarget;
  final double dailyAdSpendBudget;
  final String commissionModel;
  final bool canApproveSettlements;
  final bool canManageExpenses;
  final bool canDisbursePayouts;

  // Merchant brand creation (client)
  final String? companyName;
  final String? clientCode;
  final String merchantTier;
  final int closerLimit;
  final String? address;
  final String? city;
  final String? stateName;

  // Distribution Center roles (dcOperations, dcStockAdmin, dcFinanceAdmin, dcManager, generalAccountant, deliveryAgent)
  final String? distributionCenterId;
  final String? distributionCenterName;
  final String? assignedZone;
  final String? staffCode;
  final String? operatingState;
  final String? operatingCity;

  // Rider / PDA specific
  final String personnelType; // 'pda' | 'in_house_rider'
  final String compensationType; // 'commission' | 'salary' | 'hybrid'
  final double commissionRate;
  final double transportAllowance;
  final double fuelAllowance;
  final double failedDeliveryAllowance;
  final double baseSalary;
  final String vehicleType;
  final String vehiclePlateNumber;

  // Settlement Bank
  final String bankName;
  final String bankAccountNumber;
  final String bankAccountName;

  const OpenRegistrationRequest({
    required this.accountType,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    required this.password,
    this.clientId,
    this.clientCompanyName,
    this.supervisorId,
    this.supervisorName,
    this.dailyCallTarget = 50,
    this.dailyAdSpendBudget = 25000.0,
    this.commissionModel = 'per_form_submission',
    this.canApproveSettlements = true,
    this.canManageExpenses = true,
    this.canDisbursePayouts = true,
    this.companyName,
    this.clientCode,
    this.merchantTier = 'standard_merchant',
    this.closerLimit = 0,
    this.address,
    this.city,
    this.stateName,
    this.distributionCenterId,
    this.distributionCenterName,
    this.assignedZone,
    this.staffCode,
    this.operatingState,
    this.operatingCity,
    this.personnelType = 'pda',
    this.compensationType = 'commission',
    this.commissionRate = 1000.0,
    this.transportAllowance = 1500.0,
    this.fuelAllowance = 0.0,
    this.failedDeliveryAllowance = 500.0,
    this.baseSalary = 0.0,
    this.vehicleType = 'Motorcycle (Bajaj Boxer)',
    this.vehiclePlateNumber = '',
    this.bankName = '',
    this.bankAccountNumber = '',
    this.bankAccountName = '',
  });
}

